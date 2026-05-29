import socket
import select
import sys
import threading

def forward(source, destination):
    string = ' '
    while string:
        string = source.recv(1024)
        if string:
            destination.sendall(string)
        else:
            source.shutdown(socket.SHUT_RD)
            destination.shutdown(socket.SHUT_WR)

def serve():
    try:
        dock_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        dock_socket.bind(('0.0.0.0', 11435))
        dock_socket.listen(5)
        while True:
            client_socket, addr = dock_socket.accept()
            server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server_socket.connect(('127.0.0.1', 11434))
            threading.Thread(target=forward, args=(client_socket, server_socket)).start()
            threading.Thread(target=forward, args=(server_socket, client_socket)).start()
    except Exception as e:
        print(e)

if __name__ == '__main__':
    serve()
