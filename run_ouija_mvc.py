#!/usr/bin/env python
"""
Ouija - Balatro Seed Finder (MVC Version) - Launcher
Author: pifreak
"""

import faulthandler
faulthandler.enable()

import sys
from ouija_mvc.app import main

if __name__ == "__main__":
    sys.exit(main())