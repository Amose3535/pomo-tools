# notify.ps1

param (
    [string]$title = "Timer Finito!",
    [string]$message = "Prendiri una pausa bro!"
)

# Carica la libreria delle notifiche di sistema
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null

# Crea template della notifica
$template = [Windows.UI.Notifications.ToastTemplateType]::ToastText02
$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($template)
$textNodes = $xml.GetElementsByTagName("text")

# Inserisce titolo e messaggio
$textNodes.Item(0).AppendChild($xml.CreateTextNode($title)) > $null
$textNodes.Item(1).AppendChild($xml.CreateTextNode($message)) > $null

# Mostra la notifica
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("POMO-TOOLS")
$notifier.Show($toast)

# In godot puoi usare il seguente codice per chiamare lo script:
#
#var title = "Pomodoro completato"
#var msg = "È ora di una pausa bro!"
#
#OS.execute("powershell", [
#	"-ExecutionPolicy", "Bypass",
#	"-File", "res://notify.ps1",
#	"-title", title,
#	"-message", msg
#], false)

#Spiegazione del codice di esempio:
# OS.execute() è una funzione di Godot che permette di eseguire comandi esterni.
# "powershell" è il comando per eseguire PowerShell.
# l'array di argomenti include:
# -ExecutionPolicy Bypass: per evitare restrizioni di esecuzione degli script.
# -File: specifica il file da eseguire.
# -title e -message: passano i parametri al tuo script PowerShell.
# La funzione OS.execute() restituisce un valore booleano che indica se il comando è stato eseguito con successo o meno.
