#!/bin/bash

# generate docs in a temporary directory
FOUNDRY_PROFILE=docs forge doc --out tmp/opoo-technical-docs

# edit generated summary not to have container pages
# - [jobs](solidity/interfaces/jobs/README.md)
# should become
# - [jobs]()
# TODO

# edit generated summary titles to start with an uppercase letter
# - [jobs]()
# should become
# - [Jobs]()
# TODO

# edit the SUMMARY after the Interfaces section
# https://stackoverflow.com/questions/67086574/no-such-file-or-directory-when-using-sed-in-combination-with-find
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' -e '/\[Interfaces\]/q' docs/src/SUMMARY.md
else
  sed -i -e '/\[Interfaces\]/q' docs/src/SUMMARY.md
fi
# copy the generated SUMMARY, from the tmp directory, without the first 5 lines
# and paste them after the Interfaces section on the original SUMMARY
tail -n +5 tmp/opoo-technical-docs/src/SUMMARY.md >> docs/src/SUMMARY.md

# delete old generated interfaces docs
rm -rf docs/src/solidity/interfaces
# there are differences in cp and mv behavior between UNIX and macOS when it comes to non-existing directories
# creating the directory to circumvent them
mkdir -p docs/src/solidity/interfaces
# move new generated interfaces docs from tmp to original directory
cp -R tmp/opoo-technical-docs/src/solidity/interfaces docs/src/solidity/

# delete tmp directory
rm -rf tmp
