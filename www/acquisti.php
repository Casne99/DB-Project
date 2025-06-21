<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'cliente') {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';

$user_email = $_SESSION['user_email'];

$pdo->exec("SET search_path = develop");

try {
    $stmt = $pdo->prepare('SELECT codice_fiscale, nome, cognome FROM clienti WHERE login = :email');
    $stmt->execute([':email' => $user_email]);
    $cliente = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$cliente) {
        throw new Exception('Cliente non trovato.');
    }

    $cf = $cliente['codice_fiscale'];
    $nome = $cliente['nome'];
    $cognome = $cliente['cognome'];

    // Recupera fatture e numero di prodotti
    $stmt = $pdo->prepare("
        SELECT
            f.id,
            f.data_acquisto,
            f.totale,
            f.sconto_applicato,
            COALESCE(SUM(pf.quantita), 0) AS numero_prodotti
        FROM fatture f
        LEFT JOIN prodotti_fattura pf ON pf.fattura = f.id
        WHERE f.cliente = :cf
        GROUP BY f.id
        ORDER BY f.data_acquisto DESC
    ");
    $stmt->execute([':cf' => $cf]);
    $fatture = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (Exception $e) {
    die("Errore: " . htmlspecialchars($e->getMessage()));
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>I miei acquisti</title>
    <style>
        table {
            border-collapse: collapse;
            width: 100%;
            margin-top: 1em;
        }
        th, td {
            border: 1px solid #aaa;
            padding: 8px;
            text-align: center;
        }
        th {
            background-color: #eee;
        }
    </style>
</head>
<body>
    <h1>I miei acquisti</h1>
    <p>Cliente: <strong><?= htmlspecialchars($nome . ' ' . $cognome) ?></strong></p>

    <?php if (empty($fatture)): ?>
        <p>Non hai ancora effettuato acquisti.</p>
    <?php else: ?>
        <table>
            <thead>
                <tr>
                    <th>ID Fattura</th>
                    <th>Data Acquisto</th>
                    <th>Totale (€)</th>
                    <th>Sconto (%)</th>
                    <th>Numero Prodotti</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($fatture as $f): ?>
                    <tr>
                        <td><?= htmlspecialchars($f['id']) ?></td>
                        <td><?= htmlspecialchars($f['data_acquisto']) ?></td>
                        <td><?= number_format($f['totale'], 2, ',', '.') ?></td>
                        <td><?= number_format($f['sconto_applicato'], 2, ',', '.') ?></td>
                        <td><?= (int)$f['numero_prodotti'] ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    <?php endif; ?>

    <p><a href="dashboard.php">Torna alla dashboard</a></p>
</body>
</html>
