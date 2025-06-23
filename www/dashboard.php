<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';

$user_email = $_SESSION['user_email'];
$user_role = $_SESSION['user_role'];

$menu_config = require __DIR__ . '/config/menu.php';
$menu = $menu_config[$user_role] ?? $menu_config['default'];

$pdo->exec("SET search_path = develop");

$punti = 0;
$tessera = null;
$nome_cliente = null;
$cognome_cliente = null;
$genere_cliente = null;

try {
    if ($user_role === 'cliente') {
        $stmt = $pdo->prepare('SELECT codice_fiscale, nome, cognome, genere FROM clienti WHERE login = :email');
        $stmt->execute([':email' => $user_email]);
        $utente = $stmt->fetch();
    } elseif ($user_role === 'manager') {
        $stmt = $pdo->prepare('SELECT nome, cognome, genere FROM manager WHERE login = :email');
        $stmt->execute([':email' => $user_email]);
        $utente = $stmt->fetch();
    }

    if (!empty($utente)) {
        $nome_cliente = $utente['nome'] ?? null;
        $cognome_cliente = $utente['cognome'] ?? null;
        $genere_cliente = $utente['genere'] ?? null;

        if ($user_role === 'cliente' && isset($utente['codice_fiscale'])) {
            $cf = $utente['codice_fiscale'];
            $stmt = $pdo->prepare('SELECT punti FROM tessere WHERE proprietario = :cf');
            $stmt->execute([':cf' => $cf]);
            $tessera = $stmt->fetch();

            if ($tessera && isset($tessera['punti'])) {
                $punti = (int)$tessera['punti'];
            }
        }
    }
} catch (PDOException $e) {
    die("Errore durante il recupero dei dati utente: " . htmlspecialchars($e->getMessage()));
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Dashboard</title>
</head>
<body>
    <h1>
        <?php
            if ($genere_cliente === 'F') {
                echo 'Benvenuta,';
            } else {
                echo 'Benvenuto,';
            }
        ?>
        <?php if ($nome_cliente && $cognome_cliente): ?>
            <?= ' ' . htmlspecialchars($nome_cliente) . ' ' . htmlspecialchars($cognome_cliente) ?>
        <?php else: ?>
            <?= ' ' . htmlspecialchars($user_email) ?>
        <?php endif; ?>
        [<?= htmlspecialchars($user_role) ?>]
    </h1>

    <?php if ($user_role === 'cliente'): ?>
        <?php if ($tessera !== false && isset($tessera['punti'])): ?>
            <p>Saldo punti tessera fedeltà: <strong><?= $punti ?></strong></p>
        <?php else: ?>
            <p>Non hai richiesto una tessera fedeltà.</p>
        <?php endif; ?>
    <?php endif; ?>

    <ul>
        <?php foreach ($menu as $item): ?>
            <li><a href="<?= htmlspecialchars($item['link']) ?>"><?= htmlspecialchars($item['label']) ?></a></li>
        <?php endforeach; ?>
    </ul>

    <p><a href="cambia_password.php">Cambia Password</a></p>

    <form action="logout.php" method="POST" style="display:inline;">
        <button type="submit">Logout</button>
    </form>
</body>
</html>
