<?php
session_start();
if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';
$pdo->exec("SET search_path = develop");

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id = $_POST['id'] ?? '';
    $nome = $_POST['nome'] ?? '';
    $descrizione = $_POST['descrizione'] ?? '';
    $prezzi = $_POST['prezzi'] ?? [];

    $id = trim($id);
    $nome = trim($nome);
    $descrizione = trim($descrizione);

    if (strlen($id) !== 7) {
        header('Location: aggiungi_prodotto.php?error=1');
        exit;
    }

    if ($id === '' || $nome === '' || $descrizione === '') {
        header('Location: aggiungi_prodotto.php?error=1');
        exit;
    }

    try {
        $pdo->beginTransaction();

        $stmtProd = $pdo->prepare("
            INSERT INTO prodotti (id, nome, descrizione)
            VALUES (:id, :nome, :descrizione)
        ");
        $stmtProd->execute([
            ':id' => $id,
            ':nome' => $nome,
            ':descrizione' => $descrizione,
        ]);

        $stmtCosto = $pdo->prepare("
            INSERT INTO costi (deposito, prodotto, prezzo)
            VALUES (:deposito, :prodotto, :prezzo)
            ON CONFLICT (deposito, prodotto) DO UPDATE SET prezzo = EXCLUDED.prezzo
        ");

        foreach ($prezzi as $deposito => $prezzo) {
            $prezzo = floatval(str_replace(',', '.', $prezzo)); // gestisce anche virgola

            if ($prezzo < 0) {
                $prezzo = 0.00;
            }

            $stmtCosto->execute([
                ':deposito' => $deposito,
                ':prodotto' => $id,
                ':prezzo' => $prezzo,
            ]);
        }

        $pdo->commit();

        header('Location: aggiungi_prodotto.php?success=1');
        exit;

    } catch (PDOException $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        header('Location: aggiungi_prodotto.php?error=1');
        exit;
    }
} else {
    header('Location: aggiungi_prodotto.php');
    exit;
}
