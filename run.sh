#!/bin/bash
set -e

make
dosbox a.img
#dosbox-x -c "BOOT A ./a.img"