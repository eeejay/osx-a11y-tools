from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib import parse
import os
import sys
import argparse
import time
import webbrowser
from io import StringIO
import difflib
import pyautogui

class Capturing(list):
    def __enter__(self):
        self._stdout = sys.stdout
        sys.stdout = self._stringio = StringIO()
        return self
    def __exit__(self, *args):
        self.extend(self._stringio.getvalue().splitlines())
        del self._stringio    # free up some memory
        sys.stdout = self._stdout

class SpeechListener(HTTPServer):
  def __init__(self):
    HTTPServer.__init__(self, ('localhost', 8080), self.RequestHandler)
    self.timeout = 1

  def waitForSpeech(self, since=978307200):
      self.since = since
      self.speechData = None
      for i in range(5):
        self.handle_request()
        if self.speechData:
          return self.speechData
      return (None, 0)

  class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
      params = parse.parse_qs(parse.urlsplit(self.path).query)

      if 'timestamp' in params and 'text' in params:
        timestamp = float(params['timestamp'][0]) + 978307200
        if timestamp > self.server.since:
          self.server.speechData = (parse.unquote(params['text'][0]), timestamp)

      self.send_response(200)
      self.send_header("Content-type", "text/html")
      self.end_headers()
      self.wfile.write(b"ok")
      return

    def log_request(self, code='-', size='-'):
      pass

def run(args):
  # find browser
  browser = None;
  if (args.br):
    browser_path = "open -a " + args.br +" %s"
    browser = webbrowser.get(browser_path)
  elif (args.browser == "s"):
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

  # start voiceover
  pyautogui.hotkey("command", "f5")

  # start server here to avoid (some) startup noise
  print("Starting server....")
  speech_listener = SpeechListener()
  print("Server started...")

  time.sleep(2)
  with open(args.inputFile) as f:
    for line in f:
      line = line[:-1]
      currTime = time.time()
      if (line == "next"):
        pyautogui.hotkey("option", "ctrl","right")
      elif (line == "prev"):
        pyautogui.hotkey("option", "ctrl", "left")
      elif (line == "in"):
        pyautogui.hotkey("shift", "option", "ctrl", "down")
      elif (line == "out"):
        pyautogui.hotkey("shift", "option", "ctrl", "up")
      elif (line == "activate"):
        pyautogui.hotkey("option", "ctrl", "space")
      else:
        print("Error parsing command: {}. Skipping".format(line))

      (speech_text, speech_time) = speech_listener.waitForSpeech(currTime)
      if speech_text:
        print(speech_time - currTime)
        print(f"{speech_text}\n")
      else:
        print("timeout!")

  # quit voiceover and server
  pyautogui.hotkey("command", "f5")
  speech_listener.server_close()

def main():
  # parse arguments
  parser = argparse.ArgumentParser(description='Launch browser B \
    on a SITE or FILE and preform a series of VoiceOver commands \
    as described in the input file F. \
    The output of these commands will be printed to stdout')
  br = parser.add_mutually_exclusive_group()
  br.add_argument('browser', nargs='?', type=str, choices=['s', 'f', 'fn', 'nd'], help='the browser you\'d like to use (s safari, f firefox, fn firefox nightly, nd nightly debug)')
  br.add_argument('--br', type=str, help='abs path to the .app file for the custom browser you would like to use')
  loc = parser.add_mutually_exclusive_group()
  loc.add_argument('--file', type=str, help='the relative path to the file you want to run commands on')
  loc.add_argument('--site', type=str, help='the http(s) prefixed website you want to run commands on')
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


