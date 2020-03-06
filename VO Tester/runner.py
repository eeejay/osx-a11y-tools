from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib import parse
import os
import sys
import argparse
import time
import webbrowser
from io import StringIO
import difflib

global currTime
currTime = 978307200

class Capturing(list):
    def __enter__(self):
        self._stdout = sys.stdout
        sys.stdout = self._stringio = StringIO()
        return self
    def __exit__(self, *args):
        self.extend(self._stringio.getvalue().splitlines())
        del self._stringio    # free up some memory
        sys.stdout = self._stdout

class RequestHandler(BaseHTTPRequestHandler):
  def do_GET(self):
    params = parse.parse_qs(parse.urlsplit(self.path).query)

    if ('timestamp' in params):
      print(currTime - float(params['timestamp'][0]) - 978307200)

    if ('text' in params):
      print(parse.unquote(params['text'][0]) + '\n')

    return

def run(args):
  # find browser
  browser = None;
  if (args.browser == "s"):
    browser = webbrowser.get("safari")
  elif (args.browser == "f"):
    browser = webbrowser.get("firefox")
  elif (args.browser == "fn"):
    browser_path = "open -a /Applications/Firefox\\ Nightly.app %s"
    browser = webbrowser.get(browser_path)
  elif (args.browser == "nd"):
    browser_path = "open -a /Applications/Nightly\\ Debug.app %s"
    browser = webbrowser.get(browser_path)
  else:
    print("Cannot locate browser: {}".format(args.browser))
    sys.exit()

  # launch browser at location
  location = None
  if (args.file and args.browser == "s"):
    location = "file://" + os.path.abspath(args.file)
  elif (args.file):
    location = args.file
  else:
    location = args.site

  print("Browser is: {}".format(args.browser))
  browser.open_new_tab(location)
  time.sleep(2)

  # start voiceover
  os.system("osascript -e 'tell application \"System Events\" to key code 96 using command down'")

  # start server here to avoid (some) startup noise
  print("Starting server....")
  httpd = HTTPServer(('localhost', 8080), RequestHandler)
  httpd.timeout = 5
  print("Server started...")

  with open(args.inputFile) as f:
    for line in f:
      line = line[:-1]
      global currTime
      currTime = time.time()
      if (line == "next"):
        os.system("osascript -e 'tell application \"System Events\" to key code 124 using {option down, control down}'")
      elif (line == "prev"):
        os.system("osascript -e 'tell application \"System Events\" to key code 123 using {option down, control down}'")
      elif (line == "in"):
        os.system("osascript -e 'tell application \"System Events\" to key code 125 using {option down, control down, shift down}'")
      elif (line == "out"):
        os.system("osascript -e 'tell application \"System Events\" to key code 126 using {option down, control down, shift down}'")
      elif (line == "activate"):
        os.system("osascript -e 'tell application \"System Events\" to key code 49 using {option down, control down}'")
      else:
        print("Error parsing command: {}. Skipping".format(line))

      while (httpd.handle_request()):
        continue


  # quit voiceover and server
  os.system("osascript -e 'tell application \"System Events\" to key code 96 using command down'")
  httpd.server_close()

def main():
  # parse arguments
  parser = argparse.ArgumentParser(description='Launch browser B \
    on a SITE or FILE and preform a series of VoiceOver commands \
    as described in the input file F. \
    The output of these commands will be printed to stdout')
  parser.add_argument('browser', type=str, choices=['s', 'f', 'fn', 'nd'], help='the browser you\'d like to use (s safari, f firefox, fn firefox nightly, nd nightly debug)')
  group = parser.add_mutually_exclusive_group()
  group.add_argument('--file', type=str, help='the relative path to the file you want to run commands on')
  group.add_argument('--site', type=str, help='the http(s) prefixed website you want to run commands on')
  parser.add_argument('inputFile', type=str, help='the file containing commands to run in VoiceOver')
  parser.add_argument('--diff', type=str, choices=['s', 'f', 'fn', 'nd'], help='if you would like to create a diff of the outputs from two browsers, specify the second browser here')

  args = parser.parse_args()

  # validate file
  if not os.path.isfile(args.inputFile):
     print("File path {} does not exist. Exiting...".format(args.inputFile))
     sys.exit()

  if (args.diff):
    with Capturing() as firstOut:
      run(args)

    time.sleep(2)
    with Capturing() as secondOut:
      args.browser = args.diff
      run(args)

    for line in difflib.unified_diff(firstOut, secondOut):
      print(line)

  else:
    run(args)

if __name__== "__main__":
  main()


