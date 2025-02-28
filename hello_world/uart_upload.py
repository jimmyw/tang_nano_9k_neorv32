import sys
import time
import serial

def print_usage():
    print("Upload and execute application image via serial port (UART) to the NEORV32 bootloader.")
    print("Reset processor before starting the upload.\n")
    print("Usage:   python uart_upload.py <serial port> <NEORV32 executable>")
    print("Example: python uart_upload.py /dev/ttyS6 path/to/project/neorv32_exe.bin")

def configure_serial_port(port):
    ser = serial.Serial(
        port=port,
        baudrate=115200,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE,
        timeout=1,
        xonxoff=False,
        rtscts=False,
        dsrdtr=False
    )
    return ser

def main():
    if len(sys.argv) != 3:
        print_usage()
        sys.exit(0)

    serial_port = sys.argv[1]
    executable_path = sys.argv[2]

    try:
        ser = configure_serial_port(serial_port)
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        sys.exit(1)

    try:
        # Abort autoboot sequence
        print("Aborting autoboot...", end='')
        ser.write(b' ')
        while True:
            response = ser.read_all().decode(errors='ignore')
            print(response)

            if "CMD:>" in response:
                break

        # Erase flash memory
        print("Erasing flash memory...", end='')
        ser.write(b'e')
        while True:
            time.sleep(0.5)
            response = ser.read_all().decode(errors='ignore')
            print(response)
            if "CMD:>" in response:
                break

        # Execute upload command and get response
        print("Starting upload...", end='')
        ser.write(b'u')
        time.sleep(0.5)
        response = ser.read_all().decode(errors='ignore')
        print(response)

        # Check response
        if "Awaiting neorv32_exe.bin" not in response:
            print("Bootloader response error!")
            print("Reset processor before starting the upload.")
            ser.close()
            sys.exit(1)

        # Send executable and get response
        print("Uploading executable...", end='')
        with open(executable_path, 'rb') as exe_file:
            while True:
                chunk = exe_file.read(1024)
                if not chunk:
                    break
                ser.write(chunk)
                print("X")
                if ser.in_waiting:
                    response = ser.read().decode(errors='ignore')
                    print(response, end=None)

            ser.read_all().decode(errors='ignore')
        time.sleep(3)
        response = ser.read_all().decode()
        print(response)

        # Check response
        if "OK" not in response:
            print(" FAILED!")
            ser.close()
            sys.exit(1)

        print ("Booting application...", end='')
        ser.write(b'x')
        print(" OK")
        ser.close()
        sys.exit(0)

    except Exception as e:
        print(f"Error during upload: {e}")
        e.print_stack()
        ser.close()
        sys.exit(1)

if __name__ == "__main__":
    main()