# powershell-ptr-update
ENG
The script checks for the presence of PTR zones and their recordings against direct zones and adds or changes them to the actual ones.
For the script to work, you must specify a forward zone in "$Zone" variable.
Important: default mask for reverse zone is /24 (255.255.255.0)

RUS
Скрипт проверяет наличие птр зон и их записи относительно прямых зон и добавляет или изменяет их на актуальные.
Для работы скрипта необходимо указать прямую зону в переменной "$Zone".
Важно: по умолчанию маска для обратной зоны /24 (255.255.255.0)
