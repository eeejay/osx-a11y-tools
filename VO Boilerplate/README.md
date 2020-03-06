## VoiceOver Tester

Usage:
```
python3 runner.py --help

Launch browser B on a SITE or FILE
and preform a series of VoiceOver
commands as described in the given input
file . The output of these commands
will be printed to stdout.

positional arguments:
  {s,f,fn,nd}   the browser you'd
                like to use (s
                safari, f firefox,
                fn firefox nightly,
                nd nightly debug)
  inputFile     the file containing
                commands to run in
                VoiceOver

optional arguments:
  -h, --help    show this help
                message and exit
  --file FILE   the relative path to
                the file you want to
                run commands on
  --site SITE   the http(s) prefixed
                website you want to
                run commands on
  --diff {s,f,fn,nd}
                if you would like to
                create a diff of
                the outputs
                from two browsers,
                specify the second
                browser here

```

Sample runs:

1. Run commands in input.txt on google.com launched in safari:
`python3 runner.py s input.txt --site http://google.com`

2. Run commands in input.txt on sample.html launched in firefox nightly:
`python3 runner.py fn input.txt --file sample.html`

3. Generate a diff from running the commands in input.txt on sample.html in safari and firefox nightly:
`python3 runner.py fn input.txt --file sample.html --diff s`
