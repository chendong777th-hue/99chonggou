#!/usr/bin/env python3
"""Add NotificationService extension target to Runner.xcodeproj."""

from pathlib import Path

PBX = Path(__file__).resolve().parent / "Runner.xcodeproj" / "project.pbxproj"
text = PBX.read_text()

if "NotificationService.appex" in text:
    print("NotificationService target already present")
    raise SystemExit(0)

IDS = {
    "swift_file": "A1NS01FC26346D5854E00701",
    "assets_file": "A1NS02FC26346D5854E00702",
    "info_file": "A1NS03FC26346D5854E00703",
    "product_file": "A1NS04FC26346D5854E00704",
    "group": "A1NS05FC26346D5854E00705",
    "target": "A1NS06FC26346D5854E00706",
    "swift_build": "A1NS07FC26346D5854E00707",
    "assets_build": "A1NS08FC26346D5854E00708",
    "embed_build": "A1NS09FC26346D5854E00709",
    "sources_phase": "A1NS10FC26346D5854E00710",
    "resources_phase": "A1NS11FC26346D5854E00711",
    "frameworks_phase": "A1NS12FC26346D5854E00712",
    "embed_phase": "A1NS13FC26346D5854E00713",
    "dependency": "A1NS14FC26346D5854E00714",
    "proxy": "A1NS15FC26346D5854E00715",
    "config_list": "A1NS16FC26346D5854E00716",
    "debug_cfg": "A1NS17FC26346D5854E00717",
    "release_cfg": "A1NS18FC26346D5854E00718",
    "profile_cfg": "A1NS19FC26346D5854E00719",
}

text = text.replace(
    "/* End PBXBuildFile section */",
    f"""\t\t{IDS["swift_build"]} /* NotificationService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {IDS["swift_file"]} /* NotificationService.swift */; }};
\t\t{IDS["assets_build"]} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {IDS["assets_file"]} /* Assets.xcassets */; }};
\t\t{IDS["embed_build"]} /* NotificationService.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {IDS["product_file"]} /* NotificationService.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
/* End PBXBuildFile section */""",
)

text = text.replace(
    "/* End PBXFileReference section */",
    f"""\t\t{IDS["swift_file"]} /* NotificationService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = "<group>"; }};
\t\t{IDS["assets_file"]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
\t\t{IDS["info_file"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
\t\t{IDS["product_file"]} /* NotificationService.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = NotificationService.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */""",
)

text = text.replace(
    "/* End PBXFrameworksBuildPhase section */",
    f"""\t\t{IDS["frameworks_phase"]} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXCopyFilesBuildPhase section */
\t\t{IDS["embed_phase"]} /* Embed App Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{IDS["embed_build"]} /* NotificationService.appex in Embed App Extensions */,
\t\t\t);
\t\t\tname = "Embed App Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */""",
)

text = text.replace(
    "\t\t\t97C146F01CF9000F007C117D /* Runner */,\n\t\t\t97C146EF1CF9000F007C117D /* Products */,",
    f"\t\t\t97C146F01CF9000F007C117D /* Runner */,\n\t\t\t{IDS['group']} /* NotificationService */,\n\t\t\t97C146EF1CF9000F007C117D /* Products */,",
)
text = text.replace(
    "\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n\t\t);",
    f"\t\t\t97C146EE1CF9000F007C117D /* Runner.app */,\n\t\t\t{IDS['product_file']} /* NotificationService.appex */,\n\t\t);",
)

text = text.replace(
    "/* End PBXGroup section */",
    f"""\t\t{IDS["group"]} /* NotificationService */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{IDS["swift_file"]} /* NotificationService.swift */,
\t\t\t\t{IDS["assets_file"]} /* Assets.xcassets */,
\t\t\t\t{IDS["info_file"]} /* Info.plist */,
\t\t\t);
\t\t\tpath = NotificationService;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */""",
)

text = text.replace(
    "\t\t\t97C146EC1CF9000F007C117D /* Resources */,\n\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,",
    f"\t\t\t97C146EC1CF9000F007C117D /* Resources */,\n\t\t\t{IDS['embed_phase']} /* Embed App Extensions */,\n\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,",
)
text = text.replace(
    "\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = Runner;",
    f"\t\t\tdependencies = (\n\t\t\t\t{IDS['dependency']} /* PBXTargetDependency */,\n\t\t\t);\n\t\t\tname = Runner;",
)

text = text.replace(
    "/* End PBXNativeTarget section */",
    f"""\t\t{IDS["target"]} /* NotificationService */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {IDS["config_list"]} /* Build configuration list for PBXNativeTarget "NotificationService" */;
\t\t\tbuildPhases = (
\t\t\t\t{IDS["sources_phase"]} /* Sources */,
\t\t\t\t{IDS["frameworks_phase"]} /* Frameworks */,
\t\t\t\t{IDS["resources_phase"]} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = NotificationService;
\t\t\tproductName = NotificationService;
\t\t\tproductReference = {IDS["product_file"]} /* NotificationService.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
/* End PBXNativeTarget section */""",
)

text = text.replace(
    "\t\t\ttargets = (\n\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n\t\t\t);",
    f"\t\t\ttargets = (\n\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n\t\t\t\t{IDS['target']} /* NotificationService */,\n\t\t\t);",
)

text = text.replace(
    "\t\t\t\t97C146ED1CF9000F007C117D = {\n\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n\t\t\t\t\tLastSwiftMigration = 1100;\n\t\t\t\t};",
    f"""\t\t\t\t97C146ED1CF9000F007C117D = {{
\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;
\t\t\t\t\tLastSwiftMigration = 1100;
\t\t\t\t}};
\t\t\t\t{IDS["target"]} = {{
\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t}};""",
)

text = text.replace(
    "/* End PBXResourcesBuildPhase section */",
    f"""\t\t{IDS["resources_phase"]} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{IDS["assets_build"]} /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */""",
)

text = text.replace(
    "/* End PBXSourcesBuildPhase section */",
    f"""\t\t{IDS["sources_phase"]} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{IDS["swift_build"]} /* NotificationService.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */""",
)

insert = f"""
/* Begin PBXContainerItemProxy section */
\t\t{IDS["proxy"]} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = 97C146E61CF9000F007C117D /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {IDS["target"]};
\t\t\tremoteInfo = NotificationService;
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXTargetDependency section */
\t\t{IDS["dependency"]} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {IDS["target"]} /* NotificationService */;
\t\t\ttargetProxy = {IDS["proxy"]} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */
"""
text = text.replace("/* Begin PBXProject section */", insert + "\n/* Begin PBXProject section */")

nse_debug = f"""\t\t{IDS["debug_cfg"]} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCURRENT_PROJECT_VERSION = 9;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\t"DEVELOPMENT_TEAM[sdk=iphoneos*]" = 3KXQMRUP42;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = NotificationService/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 13.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = vip.99chat.pro.NotificationService;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};"""

nse_release = f"""\t\t{IDS["release_cfg"]} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCURRENT_PROJECT_VERSION = 9;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\t"DEVELOPMENT_TEAM[sdk=iphoneos*]" = 3KXQMRUP42;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = NotificationService/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 13.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = vip.99chat.pro.NotificationService;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Release;
\t\t}};"""

nse_profile = f"""\t\t{IDS["profile_cfg"]} /* Profile */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tCURRENT_PROJECT_VERSION = 9;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\t"DEVELOPMENT_TEAM[sdk=iphoneos*]" = 3KXQMRUP42;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = NotificationService/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 13.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = vip.99chat.pro.NotificationService;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 1;
\t\t\t}};
\t\t\tname = Profile;
\t\t}};"""

text = text.replace(
    "/* End XCBuildConfiguration section */",
    nse_debug + "\n" + nse_release + "\n" + nse_profile + "\n/* End XCBuildConfiguration section */",
)

text = text.replace(
    "/* End XCConfigurationList section */",
    f"""\t\t{IDS["config_list"]} /* Build configuration list for PBXNativeTarget "NotificationService" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{IDS["debug_cfg"]} /* Debug */,
\t\t\t\t{IDS["release_cfg"]} /* Release */,
\t\t\t\t{IDS["profile_cfg"]} /* Profile */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */""",
)

PBX.write_text(text)
print("NotificationService target added to project.pbxproj")
