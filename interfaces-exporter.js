const { execSync } = require('child_process');
const fse = require('fs-extra');
const glob = require('glob');
const path = require('path');

const packageName = `opoo-core`;
const packageDescription = `Optimistic Oracle Interfaces and needed integration files`;
const outDir = './out';
const exportDir = './npm';
const abiDir = `${exportDir}/abi`;
const contractsDir = `${exportDir}/contracts`;
const interfacesDir = './solidity/interfaces';
const interfacesGlob = `${interfacesDir}/**/*.sol`;

// empty export directory
fse.emptyDirSync(exportDir);

// create custom package.json in the export directory
const wholePackage = fse.readJsonSync('./package.json');

const extraDependencies = {
  '@ethersproject/abi': '5.7.0',
  '@ethersproject/providers': '5.7.2',
  'bn.js': '5.2.1',
  ethers: '6.0.3',
  'web3-core': '1.9.0',
};

const package = {
  name: packageName,
  description: packageDescription,
  version: wholePackage.version,
  keywords: wholePackage.keywords,
  license: wholePackage.license,
  dependencies: { ...wholePackage.dependencies, ...extraDependencies },
};

fse.writeJsonSync(`${exportDir}/package.json`, package, { spaces: 4 });

// copy README.md and LICENSE files to export directory
fse.copySync('./interfaces-readme.md', `${exportDir}/README.md`);
fse.copySync('./LICENSE', `${exportDir}/LICENSE`);

// get remappings
const remappings = fse
  .readFileSync('remappings.txt', 'utf8')
  .split('\n')
  .filter(Boolean)
  .map((line) => line.trim().split('='));

// list all of the solidity interfaces
glob(interfacesGlob, (err, interfacePaths) => {
  if (err) throw err;

  // for each interface path
  for (let interfacePath of interfacePaths) {
    const interfaceFile = fse.readFileSync(interfacePath, 'utf8');
    const relativeInterfaceFile = transformRemappings(interfaceFile, interfacePath, remappings);

    const contractPath = interfacePath.substring(interfacesDir.length + 1);
    fse.outputFileSync(path.join(contractsDir, contractPath), relativeInterfaceFile);

    // get the interface name
    const interface = interfacePath.substring(interfacePath.lastIndexOf('/') + 1, interfacePath.lastIndexOf('.'));

    // copy interface abi to the export directory
    fse.copySync(`${outDir}/${interface}.sol/${interface}.json`, `${abiDir}/${interface}.json`);
  }

  console.log(`Copied ${interfacePaths.length} interfaces`);

  const targets = ['web3-v1', 'ethers-v6'];

  for (const target of targets) {
    console.log(`Generating types for ${target}`);
    execSync(`yarn typechain --target ${target} --out-dir ${exportDir}/${target} '${abiDir}/*.json'`);
  }
});

// install package dependencies
console.log(`Installing package dependencies`);
execSync('cd npm && yarn');

// transform remappings into relative paths
function transformRemappings(file, filePath, remappings) {
  const fileLines = file.split('\n');

  return fileLines
    .map((line) => {
      // just modify imports
      if (!line.match(/^\s*import /i)) return line;

      const remapping = remappings.find(([find]) => line.match(find));
      if (!remapping) return line;

      const remappingOrigin = remapping[0];
      const remappingDestination = remapping[1];

      // converts @interfaces/IFeeManager.sol => ../../interfaces/IFeeManager.sol
      // taking into account the nested structure of the project
      const dependencyDirectory = filePath.replace(/solidity.*/, `${remappingDestination}`);
      const sourceDirectory = filePath.split('/').slice(0, -1).join('/');

      replace = path.relative(sourceDirectory, dependencyDirectory);
      // turning empty paths into ./ and attaching / to the end of non-empty paths
      replace = replace === '' ? './' : `${replace}/`;

      line = line.replace(remappingOrigin, replace);

      // transform:
      // import '../../../node_modules/some-file.sol';
      // into:
      // import 'some-file.sol';
      const modulesKey = 'node_modules/';
      if (line.includes(modulesKey)) {
        const importPart = line.substring(0, line.indexOf('.'));
        line = importPart + line.substring(line.indexOf(modulesKey) + modulesKey.length);
      }

      return line;
    })
    .join('\n');
}
