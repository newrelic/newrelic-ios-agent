# dsym-upload-tools
Python and shell scripts to upload dSYMs to {`mobile-symbol-upload.newrelic.com`,`staging-mobile-crash.newrelic.com`}

## Updating

Python 3: Update dependencies
Coming Soon!

Python 2: Update dependencies
1) install python2.7 via pyenv if necessary. install pip package manager. Identify your Python2.7 installation directory.

2) install `urllib3` updates and then run `pip show urllib3` to get your python package path.
3) install `requests` & dependencies 
4) copy the newly installed packages {`certifi`,`chardet`,`idna`,`requests`,`urllib3`} from your python2.7 packages directory to iOS agent `dsym-upload-tools` directory.

Note Python2.7 packages in a directory that looks something like this: `~/Library/Python/2.7/lib/python/site-packages` 

### Client impact
Clients expect recent Python library versions on their build machines. Security scans will often flag older Python library dependencies.

### Python version getting older
Python 2.7 was pre-installed in MacOS up until MacOS 12.3.

MacOS 12.3 comes with Python 3 installed and Python 2 will not be installed.

## Dependency versions:

certifi:  "2021.10.08"
chardet:  "4.0.0"
requests: "2.27.1"
idna:     "2.10"
urllib3:  "1.26.9"


## Testing After Updating

To test Python2 we can't actually use Xcode if we are on MacOS 12.3+  run the following commands to test the `generateMap.py` script.

```
export DSYM_UPLOAD_URL="https://staging-mobile-symbol-upload.newrelic.com"

python generateMap.py --debug "/Users/cdillard/Library/Developer/Xcode/DerivedData/Agent-enfnkmkxcqxviqepoidjuxkgcnnd/Build/Products/Debug-iphoneos/APODBrowser.app.dSYM" "AAdafe0875c6b56997560679adc20d41a5d543aa58-NRMA"
```
Note: Replace my cdillard path with the path to your apps dsym and your apps token. 
Note the maps.txt file produced and the nrdSYM{UUID}.zip file that is created and uploaded to New Relic map endpoint.