import paramiko
import sys

def main():
    hostname = "10.112.165.130"
    username = "nopapp"
    password = "nopapp@bs23"

    print(f"Connecting to {hostname} as {username}...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        client.connect(hostname, username=username, password=password, timeout=10)
        print("Connected successfully!")
        
        # Check Linux version
        print("\n=== Linux Version ===")
        stdin, stdout, stderr = client.exec_command("cat /etc/os-release")
        print(stdout.read().decode('utf-8'))
        
        # Check .NET installation
        print("=== .NET Check ===")
        stdin, stdout, stderr = client.exec_command("which dotnet")
        which_output = stdout.read().decode('utf-8').strip()
        print(f"which dotnet: {which_output}")
        
        stdin, stdout, stderr = client.exec_command("dotnet --version")
        version_output = stdout.read().decode('utf-8').strip()
        version_err = stderr.read().decode('utf-8').strip()
        print(f"dotnet --version output: {version_output}")
        if version_err:
            print(f"dotnet --version error: {version_err}")
            
        stdin, stdout, stderr = client.exec_command("dotnet --list-sdks")
        sdks_output = stdout.read().decode('utf-8').strip()
        print(f"dotnet --list-sdks:\n{sdks_output}")
        
        stdin, stdout, stderr = client.exec_command("dotnet --list-runtimes")
        runtimes_output = stdout.read().decode('utf-8').strip()
        print(f"dotnet --list-runtimes:\n{runtimes_output}")
        
    except Exception as e:
        print(f"Error occurred: {e}", file=sys.stderr)
    finally:
        client.close()

if __name__ == "__main__":
    main()
