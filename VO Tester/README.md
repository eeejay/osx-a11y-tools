## VoiceOver Tester

Prerequisites:

This script requires `pyautogui`. It can be installed with `pip3 install pyautogui`.

Usage:
```
runner.py [-h] [--br BR]
                 [--file FILE | --site SITE]
                 [--diff {s,f,fn,nd}]
                 [{s,f,fn,nd}] inputFile

Launch browser B on a SITE or FILE and preform
a series of VoiceOver commands as described in
the input file F. The output of these commands
will be printed to stdout

positional arguments:
  {s,f,fn,nd}         the browser you'd like
                      to use (s safari, f
                      firefox, fn firefox
                      nightly, nd nightly
                      debug)
  inputFile           the file containing
                      commands to run in
                      VoiceOver

optional arguments:
  -h, --help          show this help message
                      and exit
  --br BR             abs path to the .app
                      file for the custom
                      browser you would like
                      to use
  --file FILE         the relative path to the
                      file you want to run
                      commands on
  --site SITE         the http(s) prefixed
                      website you want to run
                      commands on
  --diff {s,f,fn,nd}  if you would like to
                      create a diff of the
                      outputs from two
                      browsers, specify the
                      second browser here
```

Sample runs:

1. Run commands in input.txt on google.com launched in safari:
`./runner.py s input.txt --site http://google.com`

2. Run commands in input.txt on sample.html launched in firefox nightly:
`./runner.py fn input.txt --file sample.html`

3. Generate a diff from running the commands in input.txt on sample.html in safari and firefox nightly:
`./runner.py fn input.txt --file sample.html --diff s`

4. Run commands in input.txt on sample.html launched in custom debug build:
`./runner.py --br ~/path/to/NightlyDebug.app  input.txt --file sample.html`
