# dsym-upload-tools
Python and shell scripts to upload dSYMs to {`mobile-symbol-upload.newrelic.com`,`staging-mobile-crash.newrelic.com`}

## Updating
1) install pip package manager `python get-pip.py`
2) install `urllib3` updates `~/Library/Python/2.7/bin/pip install "urllib3"`
3) install `requests` & dependencies `~/Library/Python/2.7/bin/pip install "requests"`
4) copy the newly installed packages {`certifi`,`chardet`,`idna`,`requests`,`urllib3`} from `~/Library/Python/2.7/lib/python/site-packages` to iOS agent `dsym-upload-tools` directory.

## Notes
### Client impact
Clients expect recent Python library versions on their build machines. Security scans will often flag older Python library dependencies.

### Python version getting older
Python 2.7 is pre-installed on the MacOS Catalina, but is reaching end of life. 


