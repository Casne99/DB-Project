<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Gestione Clienti</title>
</head>
<body>
    <h1>Gestione Clienti</h1>

    <ul>
        <li><a href="add_user.php">Aggiungi nuovo cliente</a></li>
    </ul>

    <p><a href="dashboard.php">Torna alla Dashboard</a></p>
</body>
</html>
