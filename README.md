# powershell-ptr-update
### ENG
The script checks for the presence of reverse zones and their PTR records against direct zones and adds or changes them to the actual ones.

For the script to work, you must specify a forward zone in `$Zone` variable.

Important: default mask for reverse zone creation is /24 (255.255.255.0)

### RUS
Скрипт проверяет наличие обратных зон и их записи относительно прямых зон и добавляет или изменяет их на актуальные.

Для работы скрипта необходимо указать прямую зону в переменной `$Zone`.

Важно: по умолчанию маска для создания обратной зоны /24 (255.255.255.0)
