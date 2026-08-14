#!/usr/bin/env python3
"""Patch the generated ios/Runner.xcodeproj/project.pbxproj for the iOS port.

Adds:
- ServicePlugin.swift to the Runner target sources
- libclash.a to the Runner target link flags (OTHER_LDFLAGS)
- bumps IPHONEOS_DEPLOYMENT_TARGET to 15.1
"""
import sys
import uuid

PBXPROJ = sys.argv[1]
LIBCLASH = sys.argv[2] if len(sys.argv) > 2 else "$(PROJECT_DIR)/Runner/libclash/libclash.a"


def new_id():
    return uuid.uuid4().hex[:24].upper()


def insert_into_section(text, section_marker, entry):
    start = text.index(section_marker)
    nl = text.index("\n", start) + 1
    return text[:nl] + entry + text[nl:]


with open(PBXPROJ) as f:
    text = f.read()

bridge_id = new_id()
bridge_ref = new_id()
service_id = new_id()
service_ref = new_id()

bridge_build_entry = (
    f'\t\t{bridge_id} /* libclash_bridge.c in Sources */ = '
    f'{{isa = PBXBuildFile; fileRef = {bridge_ref} /* libclash_bridge.c */; }};\n'
)
service_build_entry = (
    f'\t\t{service_id} /* ServicePlugin.swift in Sources */ = '
    f'{{isa = PBXBuildFile; fileRef = {service_ref} /* ServicePlugin.swift */; }};\n'
)
text = insert_into_section(
    text, "/* Begin PBXBuildFile section */", bridge_build_entry + service_build_entry
)

bridge_ref_entry = (
    f'\t\t{bridge_ref} /* libclash_bridge.c */ = '
    f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.c.c; '
    f'path = libclash_bridge.c; sourceTree = "<group>"; }};\n'
)
service_ref_entry = (
    f'\t\t{service_ref} /* ServicePlugin.swift */ = '
    f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
    f'path = ServicePlugin.swift; sourceTree = "<group>"; }};\n'
)
text = insert_into_section(
    text, "/* Begin PBXFileReference section */", bridge_ref_entry + service_ref_entry
)

runner_group = "97C146F01CF9000F007C117D /* Runner */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = ("
assert runner_group in text, "Runner group not found"
text = text.replace(
    runner_group,
    runner_group
    + f"\n\t\t\t\t{bridge_ref} /* libclash_bridge.c */,"
    + f"\n\t\t\t\t{service_ref} /* ServicePlugin.swift */,",
    1,
)

sources_anchor = "\t\t\t\t74858FAF1ED2DC5600515810 /* AppDelegate.swift in Sources */,"
assert sources_anchor in text, "Runner Sources phase not found"
text = text.replace(
    sources_anchor,
    sources_anchor
    + f"\n\t\t\t\t{bridge_id} /* libclash_bridge.c in Sources */,"
    + f"\n\t\t\t\t{service_id} /* ServicePlugin.swift in Sources */,",
    1,
)

bridging_anchor = 'SWIFT_OBJC_BRIDGING_HEADER = "Runner/Runner-Bridging-Header.h";'
assert bridging_anchor in text, "Bridging header build setting not found"
text = text.replace(
    bridging_anchor,
    bridging_anchor + f'\n\t\t\t\tOTHER_LDFLAGS = "$(inherited) {LIBCLASH}";',
)

text = text.replace(
    "IPHONEOS_DEPLOYMENT_TARGET = 13.0;",
    "IPHONEOS_DEPLOYMENT_TARGET = 15.1;",
)

with open(PBXPROJ, "w") as f:
    f.write(text)

print("patched %s" % PBXPROJ)
