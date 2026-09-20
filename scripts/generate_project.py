#!/usr/bin/env python3
"""Generate the checked-in Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parent.parent
objects = {}

def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def add(object_name, isa, **fields):
    key = uid(object_name)
    objects[key] = dict(isa=isa, **fields)
    return key

def encode(value, depth=0):
    pad = '\t' * depth
    if isinstance(value, dict):
        lines = [f'{pad}\t{json.dumps(k)} = {encode(v, depth + 1)};' for k, v in value.items()]
        return '{\n' + '\n'.join(lines) + '\n' + pad + '}'
    if isinstance(value, list):
        return '(\n' + ''.join(f'{pad}\t{encode(v, depth + 1)},\n' for v in value) + pad + ')'
    return str(value) if isinstance(value, int) else json.dumps(value)

source_refs, builds, resource_builds = [], [], []
for path in sorted((ROOT / 'app').glob('*')):
    if path.suffix == '.xcassets':
        ref = add('file:' + path.name, 'PBXFileReference', lastKnownFileType='folder.assetcatalog', path=path.name, sourceTree='<group>')
        source_refs.append(ref)
        resource_builds.append(add('build:' + path.name, 'PBXBuildFile', fileRef=ref))
        continue
    if path.suffix not in ('.swift', '.plist', '.entitlements'):
        continue
    kind = {'.swift': 'sourcecode.swift', '.plist': 'text.plist.xml', '.entitlements': 'text.plist.entitlements'}[path.suffix]
    ref = add('file:' + path.name, 'PBXFileReference', lastKnownFileType=kind, path=path.name, sourceTree='<group>')
    source_refs.append(ref)
    if path.suffix == '.swift':
        builds.append(add('build:' + path.name, 'PBXBuildFile', fileRef=ref))

app_group = add('app-group', 'PBXGroup', children=source_refs, path='app', sourceTree='<group>')
product = add('product', 'PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0, path='Daybook.app', sourceTree='BUILT_PRODUCTS_DIR')
products = add('products', 'PBXGroup', children=[product], name='Products', sourceTree='<group>')
manifest = add('manifest', 'PBXFileReference', lastKnownFileType='sourcecode.swift', path='Package.swift', sourceTree='<group>')
root_group = add('root-group', 'PBXGroup', children=[app_group, manifest, products], sourceTree='<group>')
package = add('core-package', 'XCLocalSwiftPackageReference', relativePath='.')
dependency = add('core-product', 'XCSwiftPackageProductDependency', package=package, productName='DaybookCore')
core_link = add('core-link', 'PBXBuildFile', productRef=dependency)
sources = add('sources', 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=builds, runOnlyForDeploymentPostprocessing=0)
frameworks = add('frameworks', 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[core_link], runOnlyForDeploymentPostprocessing=0)
resources = add('resources', 'PBXResourcesBuildPhase', buildActionMask=2147483647, files=resource_builds, runOnlyForDeploymentPostprocessing=0)

def configuration_list(prefix, common, debug, release):
    configs = []
    for name, extra in [('Debug', debug), ('Release', release)]:
        configs.append(add(prefix + name, 'XCBuildConfiguration', buildSettings={**common, **extra}, name=name))
    return add(prefix + 'configs', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')

project_configs = configuration_list('project-', {
    'CLANG_ENABLE_MODULES': 'YES', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0', 'SDKROOT': 'iphoneos',
    'SWIFT_VERSION': '5.0', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES',
}, {'DEBUG_INFORMATION_FORMAT': 'dwarf', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG'},
   {'DEBUG_INFORMATION_FORMAT': 'dwarf-with-dsym', 'SWIFT_COMPILATION_MODE': 'wholemodule'})
target_configs = configuration_list('target-', {
    'ASSETCATALOG_COMPILER_APPICON_NAME': 'app-icon',
    'CODE_SIGN_STYLE': 'Automatic', 'CODE_SIGN_ENTITLEMENTS': 'app/Daybook.entitlements',
    'INFOPLIST_FILE': 'app/Info.plist', 'GENERATE_INFOPLIST_FILE': 'NO',
    'PRODUCT_BUNDLE_IDENTIFIER': 'local.daybook.personal', 'PRODUCT_NAME': '$(TARGET_NAME)',
    'TARGETED_DEVICE_FAMILY': '1', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
    'SUPPORTS_MACCATALYST': 'NO', 'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks'],
}, {}, {})
target = add('target', 'PBXNativeTarget', buildConfigurationList=target_configs, buildPhases=[sources, frameworks, resources],
             buildRules=[], dependencies=[], name='Daybook', packageProductDependencies=[dependency], productName='Daybook',
             productReference=product, productType='com.apple.product-type.application')
project = add('project', 'PBXProject', attributes={'BuildIndependentTargetsInParallel': 'YES', 'LastUpgradeCheck': '1600',
    'TargetAttributes': {target: {'CreatedOnToolsVersion': '16.0', 'SystemCapabilities': {'com.apple.HealthKit': {'enabled': 1}}}}},
    buildConfigurationList=project_configs, compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0,
    knownRegions=['en', 'Base'], mainGroup=root_group, packageReferences=[package], productRefGroup=products,
    projectDirPath='', projectRoot='', targets=[target])
directory = ROOT / 'daybook.xcodeproj'
directory.mkdir(exist_ok=True)
(directory / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + encode({'archiveVersion': 1, 'classes': {}, 'objectVersion': 56, 'objects': objects, 'rootObject': project}) + '\n')
scheme = directory / 'xcshareddata/xcschemes'
scheme.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Daybook.app" BlueprintName="Daybook" ReferencedContainer="container:daybook.xcodeproj"/>'
(scheme / 'Daybook.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print('Generated daybook.xcodeproj and the shared Daybook scheme.')
