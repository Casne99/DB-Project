<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    header('Location: login.php');
    exit;
}

$user_email = $_SESSION['user_email'];
$user_role = $_SESSION['user_role'];
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Dashboard</title>
</head>
<body>
    <h1>Benvenuto, <?= htmlspecialchars($user_email) . "! [" . htmlspecialchars($user_role) . "]" ?></h1>

    <p><a href="cambia_password.php">Cambia Password</a></p>

    <form action="logout.php" method="POST" style="display:inline;">
        <button type="submit">Logout</button>
    </form>
</body>
</html>
