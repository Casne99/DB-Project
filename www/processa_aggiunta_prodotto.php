<?php
session_start();
if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';
require_once __DIR__ . '/../utils/php/utils.php';

$id = strtoupper(trim($_POST['id'] ?? ''));
$nome = trim($_POST['nome'] ?? '');
$descrizione = trim($_POST['descrizione'] ?? '');

if (empty($id) || empty($nome) || empty($descrizione)) {
    header('Location: aggiungi_prodotto.php?error=1');
    exit;
}

if (aggiungi_prodotto($pdo, $id, $nome, $descrizione)) {
    header('Location: aggiungi_prodotto.php?success=1');
    exit;
} else {
    header('Location: aggiungi_prodotto.php?error=1');
    exit;
}
