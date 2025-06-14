import bcrypt

plain = 'password-goes-here'.encode('utf-8')
hashed = bcrypt.hashpw(plain, bcrypt.gensalt())

print(hashed.decode())
