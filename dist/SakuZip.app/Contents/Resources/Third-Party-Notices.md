# Third-Party Notices

## minizip-ng 4.2.2

SakuZip includes selected source files from
[zlib-ng/minizip-ng](https://github.com/zlib-ng/minizip-ng), commit
`7b2387161c542fa9f427352dcdef76097d0d692b` (tag `4.2.2`), for ZIP64,
Traditional PKWARE encryption, and WinZip AES-256 support.

SakuZip carries a small local change in `mz_zip_rw.c` so a non-zero return
from entry/progress callbacks immediately stops an operation. This connects
the library to SakuZip pause and cancellation controls.

minizip-ng is distributed under the zlib license. The complete upstream
license is retained at:

`Sources/CSakuZipArchive/minizip/LICENSE`
