"""Read-only RE8 TDB69 inspection. Does not start, attach to, or modify the game.

Usage: python RE8Patch.InspectMenus.py PATH_TO_RE8_EXE --output evidence.json
TDB layouts match the vendored SDK's RETypeDB.hpp/RETypeDefinition.hpp tdb69.
Static readonly hashes are initialized at runtime; this tool reports field names
and types, never invents their values or infers actual menu visibility.
"""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path


class TDB69:
    def __init__(self, executable):
        self.data = Path(executable).read_bytes()
        signature = struct.pack('<II', 0x00424454, 69)
        candidates = [match.start() for match in re.finditer(re.escape(signature), self.data)]
        candidates = [at for at in candidates if at + 0xE0 < len(self.data)
                      and 0 < self.u32(at + 12) < 262144]
        if len(candidates) != 1:
            raise ValueError(f'Expected one TDB69 header, found {len(candidates)}')
        self.base = candidates[0]
        self.types = self.pointer(0x60)
        self.type_impl = self.pointer(0x68)
        self.methods = self.pointer(0x70)
        self.method_impl = self.pointer(0x78)
        self.fields = self.pointer(0x80)
        self.field_impl = self.pointer(0x88)
        self.parameters = self.pointer(0xA8)
        self.strings = self.pointer(0xC8)
        self.bytes = self.pointer(0xD0)
        self.type_count = self.u32(self.base + 12)
        self.names = {}

    def u32(self, at):
        return struct.unpack_from('<I', self.data, at)[0]

    def u64(self, at):
        return struct.unpack_from('<Q', self.data, at)[0]

    def pointer(self, offset):
        result = self.base + self.u64(self.base + offset)
        if not 0 <= result < len(self.data):
            raise ValueError('TDB pointer outside file')
        return result

    def string(self, offset):
        at = self.strings + offset
        end = self.data.index(0, at)
        return self.data[at:end].decode('utf-8')

    def type_name(self, index):
        if index == 0:
            return 'void'
        if index in self.names:
            return self.names[index]
        at = self.types + index * 0x50
        impl = self.type_impl + ((self.u64(at + 8) >> 36) & 0x3FFFF) * 0x30
        name = self.string(self.u32(impl))
        namespace = self.string(self.u32(impl + 4))
        declaring_type = (self.u64(at) >> 36) & 0x3FFFF
        if declaring_type:
            name = self.type_name(declaring_type) + '.' + name
        elif namespace:
            name = namespace + '.' + name
        self.names[index] = name
        return name

    def parameter_type(self, parameter_index):
        return self.type_name(self.u32(self.parameters + parameter_index * 12 + 8) & 0x3FFFF)

    def describe(self, index):
        at = self.types + index * 0x50
        impl = self.type_impl + ((self.u64(at + 8) >> 36) & 0x3FFFF) * 0x30
        method_count = struct.unpack_from('<H', self.data, impl + 0x12)[0]
        methods = []
        for offset in range(method_count):
            method_index = self.u32(at + 0x28) + offset
            bits = self.u64(self.methods + method_index * 16)
            method_impl = self.method_impl + ((bits >> 18) & 0xFFFFF) * 12
            param_list = self.bytes + (bits >> 38)
            count = struct.unpack_from('<H', self.data, param_list)[0]
            methods.append({
                'name': self.string(self.u32(method_impl + 8)),
                'return': self.parameter_type(self.u32(param_list + 4)),
                'parameters': [self.parameter_type(self.u32(param_list + 8 + i * 4))
                               for i in range(count)]
            })
        fields = []
        for offset in range(self.u32(impl + 0x14)):
            field_index = self.u32(at + 0x2C) + offset
            bits = self.u64(self.fields + field_index * 8)
            field_impl = self.field_impl + ((bits >> 18) & 0xFFFFF) * 12
            fields.append({
                'name': self.string(self.u32(field_impl + 8) & 0x3FFFFFFF),
                'type': self.type_name(self.u32(field_impl + 4) & 0x3FFFF),
                'flags': hex(struct.unpack_from('<H', self.data, field_impl + 2)[0])
            })
        return {'type': self.type_name(index), 'methods': methods, 'fields': fields}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('executable', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--type', dest='extra_types', action='append', default=[], help='Additional exact reflected type name')
    args = parser.parse_args()
    tdb = TDB69(args.executable)
    relevant = {'app.MenuDefine', 'app.GUIManager', 'app.MenuManager', 'app.GUIDriver',
                'app.GUIMouseCursor', 'app.GUIHandle', 'app.GUIStatus',
                'app.MenuManagerUserData.Unit'}
    relevant.update(args.extra_types)
    result = {
        'source': str(args.executable.resolve()),
        'sha256': hashlib.sha256(tdb.data).hexdigest(),
        'evidence_kind': 'Offline metadata only; no menu runtime or latency verification',
        'tdb_version': 69,
        'tdb_file_offset': hex(tdb.base),
        'types': [tdb.describe(index) for index in range(1, tdb.type_count)
                  if tdb.type_name(index) in relevant]
    }
    output = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding='utf-8')
        print(f'Inspected {len(result["types"])} types; wrote {args.output}')
    else:
        print(output)


if __name__ == '__main__':
    main()
