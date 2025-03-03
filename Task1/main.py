import itertools
import string
import tkinter as tk
from tkinter import messagebox

users = {
    "admin": "admin",
    "user": "runner",
    "rana": "AaBbC",
    "hacker": "LmNop"
}


def load_dictionary(filename):
     with open(filename, "r") as file:
        return [line.strip() for line in file.readlines()]


def dictionary_attack(username, password_list, correct_password):
    for password in password_list:
        if password == correct_password:
            return True, password
    return False, None


def brute_force_attack(correct_password):
    chars = string.ascii_letters
    for combination in itertools.product(chars, repeat=5):
        password = ''.join(combination)
        if password == correct_password:
            return password
    return None


def attempt_login():
    username = entry_username.get()
    dictionary = load_dictionary("dictionary.txt")

    if username not in users:
        messagebox.showerror("Error", "Username not found!")
        return

    correct_password = users[username]
    found, password = dictionary_attack(username, dictionary, correct_password)
    if found:
        messagebox.showinfo("Success", f"Dictionary attack succeeded! Password: {password}")
        return

    messagebox.showinfo("Info", "Dictionary attack failed! Starting brute force attack...")
    brute_force_password = brute_force_attack(correct_password)
    if brute_force_password:
        messagebox.showinfo("Success", f"Brute force attack succeeded! Password: {brute_force_password}")
    else:
        messagebox.showerror("Failure", "Brute force attack failed!")


#GUI
root = tk.Tk()
root.title("Dictionary & Brute Force Attack")
root.geometry("400x200")

tk.Label(root, text="Enter Username:").pack(pady=5)
entry_username = tk.Entry(root)
entry_username.pack(pady=5)

tk.Button(root, text="Start Attack", command=attempt_login).pack(pady=10)

root.mainloop()
