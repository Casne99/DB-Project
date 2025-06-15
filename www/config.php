<?php
$host = 'localhost';
$port = 5432;
$dbname = 'catena_negozi';
$user = 'user';
$pass = 'pw';

$dsn = "pgsql:host=$host;port=$port;dbname=$dbname";

try {
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
} catch (PDOException $e) {
    die("Errore nella connessione: " . htmlspecialchars($e->getMessage()));
}
?>
