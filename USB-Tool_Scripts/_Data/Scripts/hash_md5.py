import hashlib
import os
import subprocess
import sys

def formatted_size(size_in_bytes):
    # Return the given bytes as a human friendly KB, MB, GB, or TB string
    B = float(size_in_bytes)
    KB = float(1024)
    MB = float(KB ** 2) # 1,048,576 bytes
    GB = float(KB ** 3) # 1,073,741,824 bytes
    TB = float(KB ** 4) # 1,099,511,627,776 bytes
    if B < KB:
        return '{0} {1}'.format(B,'Bytes' if 0 == B > 1 else 'Byte')
    elif KB <= B < MB:
        return '{0:.2f} KB'.format(B/KB)
    elif MB <= B < GB:
        return '{0:.2f} MB'.format(B/MB)
    elif GB <= B < TB:
        return '{0:.2f} GB'.format(B/GB)
    elif TB <= B:
        return '{0:.2f} TB'.format(B/TB)
# Creates md5 checksum digest file

def md5(file_to_hash):
# Creates md5 checksum digest file
    try:
        size = os.path.getsize(file_to_hash)
        if os.path.isfile(file_to_hash + ".md5") or file_to_hash[-4:] == ".md5":
            print("Checksum already exists, file skipped...")
            return
        tail = os.path.split(file_to_hash)[1]
        print("Hashing " + formatted_size(size) + " \'" + tail + "\'...") # should end with (, end = "") but it delays output?
        md5_hash = hashlib.md5()
        with open(file_to_hash, "rb") as f:
            # Read and update hash in chunks of 4kb
            for byte_block in iter(lambda: f.read(4096),b""):
                md5_hash.update(byte_block)
        output = str(md5_hash.hexdigest().upper()) + " *" + tail
        new_file = open(file_to_hash + ".md5", "x")
        new_file.write(output + "\n")
        new_file.close()
        subprocess.check_call(["attrib", "+H", file_to_hash + ".md5"]) # make .md5 file hidden
        print(" " * 100, end = "\r") # clear previous print line
        print("Digest file created:\n" + output)
    except FileNotFoundError:
        print("File does not exist...")



# print("[ MD5 Checksum Script ]")
# while True:
#     print("File to hash:")
#     print("> ", end = "")
#     file_to_hash = input()
#     if file_to_hash:
#         md5(file_to_hash)
#     print()

print("[ File: " + str(sys.argv[1]) + " ]")
md5(str(sys.argv[1]))
# print()

# Create a queue to manage hashing
