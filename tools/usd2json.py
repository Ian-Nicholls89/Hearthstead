#!/usr/bin/env python3
"""Converts static Quaternius .usda models (from the CC0 quaternius-stage repo) into
a small JSON mesh: triangles with per-corner positions, normals and colours, the
material colours baked in. tools/build_assets.gd then turns these into Godot meshes.

Usage: usd2json.py in.usda out.json
Handles what those packs use: nested Xforms with translate/rotateXYZ/scale ops,
Mesh prims with faceVarying or vertex normals, GeomSubset material bindings,
UsdPreviewSurface diffuseColor, and an optional faceVarying colour primvar.
"""
import json
import math
import re
import sys


def parse_vec(s):
    return [float(x) for x in s.strip("() ").split(",")]


def parse_array(s):
    s = s.strip()
    assert s.startswith("[") and s.endswith("]"), s[:40]
    body = s[1:-1].strip()
    if not body:
        return []
    if body.startswith("("):
        return [parse_vec(m) for m in re.findall(r"\([^()]*\)", body)]
    return [float(x) if "." in x or "e" in x else int(x) for x in body.split(",")]


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def m_translate(t):
    return [[1, 0, 0, t[0]], [0, 1, 0, t[1]], [0, 0, 1, t[2]], [0, 0, 0, 1]]


def m_scale(s):
    return [[s[0], 0, 0, 0], [0, s[1], 0, 0], [0, 0, s[2], 0], [0, 0, 0, 1]]


def m_rot(axis, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    if axis == 0:
        return [[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1]]
    if axis == 1:
        return [[c, 0, s, 0], [0, 1, 0, 0], [-s, 0, c, 0], [0, 0, 0, 1]]
    return [[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]


def apply(m, p, w=1.0):
    return [m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] * w for i in range(3)]


class Prim:
    def __init__(self, kind, name, parent):
        self.kind, self.name, self.parent = kind, name, parent
        self.attrs, self.children = {}, []
        self.path = (parent.path if parent else "") + "/" + name if name else ""


def parse(text):
    root = Prim("root", "", None)
    stack = [root]
    pending = None
    depth_paren = 0
    last_attr = None
    for raw in text.splitlines():
        line = raw.strip()
        if depth_paren:
            m = re.match(r'interpolation\s*=\s*"(\w+)"', line)
            if m and last_attr:
                stack[-1].attrs[last_attr + ".interp"] = m.group(1)
            depth_paren += line.count("(") - line.count(")")
            continue
        m = re.match(r'(def|over|class)\s+(\w+)?\s*"([^"]+)"\s*(\(?)', line)
        if m:
            pending = Prim(m.group(2) or "", m.group(3), stack[-1])
            stack[-1].children.append(pending)
            if m.group(4) and not line.endswith(")"):
                depth_paren = line.count("(") - line.count(")")
            continue
        if line == "{":
            stack.append(pending if pending else Prim("", "", stack[-1]))
            pending = None
            continue
        if line == "}":
            stack.pop()
            continue
        m = re.match(r"(?:uniform\s+)?[\w\[\]]+\s+([\w:]+)\s*=\s*(.*)$", line)
        if m and len(stack) > 1:
            value = m.group(2)
            if value.startswith("<") and value.endswith(">"):
                value = value[1:-1]          # a relationship target
            if value.endswith("(") and not value.endswith("[("):
                # metadata block (interpolation, elementSize) follows the value
                value = value[:-1].rstrip()
                depth_paren = 1
            stack[-1].attrs[m.group(1)] = value
            last_attr = m.group(1)
            continue
        m = re.match(r"rel\s+([\w:]+)\s*=\s*<([^>]+)>", line)
        if m and len(stack) > 1:
            stack[-1].attrs[m.group(1)] = m.group(2)
            continue
        m = re.match(r"interpolation\s*=\s*\"(\w+)\"", line)
        if m and len(stack) > 1:
            stack[-1].attrs["_interp_last"] = m.group(1)
    return root


def local_xform(p):
    m = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    order = p.attrs.get("xformOpOrder")
    if not order:
        return m
    for op in re.findall(r'"([^"]+)"', order):
        v = parse_vec(p.attrs[op])
        if op.startswith("xformOp:translate"):
            m = mat_mul(m, m_translate(v))
        elif op.startswith("xformOp:rotateXYZ"):
            # USD rotateXYZ turns about X first, then Y, then Z
            m = mat_mul(m, mat_mul(mat_mul(m_rot(2, v[2]), m_rot(1, v[1])), m_rot(0, v[0])))
        elif op.startswith("xformOp:scale"):
            m = mat_mul(m, m_scale(v))
    return m


def walk(p, fn, m):
    m = mat_mul(m, local_xform(p))
    fn(p, m)
    for c in p.children:
        walk(c, fn, m)


def convert(path):
    text = open(path).read()
    root = parse(text)
    prims = {}

    def index(p, _m):
        prims[p.path] = p
    walk(root, index, [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])
    colors = {}
    for p in prims.values():
        if p.kind == "Material":
            for c in p.children:
                if "inputs:diffuseColor" in c.attrs:
                    colors[p.path] = parse_vec(c.attrs["inputs:diffuseColor"])
    out = {"pos": [], "nrm": [], "col": []}

    def mesh(p, m):
        if p.kind != "Mesh":
            return
        counts = parse_array(p.attrs["faceVertexCounts"])
        idx = parse_array(p.attrs["faceVertexIndices"])
        pts = parse_array(p.attrs["points"])
        nrm = parse_array(p.attrs["normals"]) if "normals" in p.attrs else None
        face_col = [colors.get(p.attrs.get("material:binding"), [0.6, 0.6, 0.6])] * len(counts)
        for c in p.children:
            if c.kind == "GeomSubset" and "indices" in c.attrs:
                col = colors.get(c.attrs.get("material:binding"), [0.6, 0.6, 0.6])
                for f in parse_array(c.attrs["indices"]):
                    face_col[f] = col
        corner = 0
        for f, n in enumerate(counts):
            ids = list(range(corner, corner + n))
            for k in range(1, n - 1):
                for ci in (ids[0], ids[k], ids[k + 1]):
                    out["pos"].append([round(x, 5) for x in apply(m, pts[idx[ci]])])
                    if nrm is not None:
                        nv = nrm[ci] if p.attrs.get("normals.interp", "faceVarying") == "faceVarying" else nrm[idx[ci]]
                        nn = apply(m, nv, 0.0)
                        ln = math.sqrt(sum(x * x for x in nn)) or 1.0
                        out["nrm"].append([round(x / ln, 4) for x in nn])
                    out["col"].append([round(x, 4) for x in face_col[f]])
            corner += n
    walk(root, mesh, [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])
    return out


if __name__ == "__main__":
    data = convert(sys.argv[1])
    json.dump(data, open(sys.argv[2], "w"), separators=(",", ":"))
    ys = [p[1] for p in data["pos"]]
    print("%s: %d tris, height %.2f" % (sys.argv[1].split("/")[-1], len(data["pos"]) // 3, max(ys) - min(ys)))
