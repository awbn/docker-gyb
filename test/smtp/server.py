# A fake SMTP server for test/mail.sh: one session on 127.0.0.1:2525, without TLS.
# Writes the credentials and message it is sent to the file named, and creates
# <file>.ready once it's listening.
import base64, socket, sys

log = open(sys.argv[1], "w", buffering=1)
s = socket.create_server(("127.0.0.1", 2525))
open(sys.argv[1] + ".ready", "w").close()
f = s.accept()[0].makefile("rwb")


def send(*lines):
    f.write(b"".join(line.encode() + b"\r\n" for line in lines))
    f.flush()


def recv():
    return f.readline().decode().rstrip("\r\n")


send("220 test")
while line := recv():
    word = line.upper()
    if word.startswith("EHLO"):
        send("250-test", "250 AUTH PLAIN")
    elif word.startswith("AUTH PLAIN"):
        token = line.split(" ")[2] if line.count(" ") > 1 else (send("334 "), recv())[1]
        log.write("AUTH " + base64.b64decode(token).decode().replace("\0", "|") + "\n")
        send("235 ok")
    elif word.startswith("DATA"):
        send("354 go")
        while (body := recv()) != ".":
            log.write("BODY " + body + "\n")
        send("250 ok")
    elif word.startswith("QUIT"):
        send("221 bye")
        break
    else:
        send("250 ok")
