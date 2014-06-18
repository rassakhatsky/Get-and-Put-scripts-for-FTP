Get-and-Put-scripts-for-FTP
===========================
GET Examples:
sh -x ./fops_ftp.sh -c get -s user:password@localhost -d /ss/ -f /dev/1.txt
sh -x ./fops_ftp.sh -c get -s user:password@localhost -d /ss/ -f /dev/

PUT Example:
sh -x ./fops_sftp.sh -c put -s user:password@localhost -f /1.txt -d /1.txt
