import bcrypt
import inputs
import csv

with open('hashed_passwords.csv', mode='w', newline='', encoding='utf-8') as file:
    writer = csv.writer(file)
    writer.writerow(['Password', 'Hashed'])

    for password in inputs.plain_passwords:
        password_bytes = password.encode('utf-8')
        hashed = bcrypt.hashpw(password_bytes, bcrypt.gensalt())
        writer.writerow([password, hashed.decode('utf-8')])
