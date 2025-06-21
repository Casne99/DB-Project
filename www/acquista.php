<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
    header('Location: login.php');
    exit;
}

require_once __DIR__ . '/config/db.php';

$pdo->exec("SET search_path = develop");

$user_email = $_SESSION['user_email'];
$user_role = $_SESSION['user_role'];

$deposito_selezionato = $_GET['deposito'] ?? null;
$prodotti = [];
$negozi = [];

try {
    $stmt = $pdo->prepare("
        SELECT id, orario_apertura, orario_chiusura
        FROM negozi
        WHERE attivo = true
        ORDER BY id
    ");
    $stmt->execute();
    $negozi = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if ($deposito_selezionato) {
        $stmtProd = $pdo->prepare("
            SELECT p.id, p.nome, d.quantita
            FROM disponibilita d
            JOIN prodotti p ON d.prodotto = p.id
            JOIN negozi n ON d.deposito = n.id
            WHERE d.deposito = :deposito
              AND n.attivo = true
              AND d.quantita > 0
            ORDER BY p.nome
        ");
        $stmtProd->execute([':deposito' => $deposito_selezionato]);
        $prodotti = $stmtProd->fetchAll(PDO::FETCH_ASSOC);
    }
} catch (PDOException $e) {
    die("Errore database: " . htmlspecialchars($e->getMessage()));
}
?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Acquista Prodotti</title>
</head>
<body>
    <h1>Seleziona un negozio per vedere i prodotti disponibili</h1>

    <form method="GET" action="acquista.php">
        <label for="deposito">Negozio:</label>
        <select name="deposito" id="deposito" onchange="this.form.submit()">
            <option value="">-- Seleziona un negozio --</option>
            <?php foreach ($negozi as $negozio): ?>
                <option value="<?= htmlspecialchars($negozio['id']) ?>"
                    <?= ($deposito_selezionato === $negozio['id']) ? 'selected' : '' ?>>
                    <?= htmlspecialchars($negozio['id']) ?>
                    (<?= substr($negozio['orario_apertura'], 0, 5) ?> - <?= substr($negozio['orario_chiusura'], 0, 5) ?>)
                </option>
            <?php endforeach; ?>
        </select>
    </form>

    <?php if ($deposito_selezionato): ?>
        <h2>Prodotti disponibili presso il negozio <?= htmlspecialchars($deposito_selezionato) ?></h2>

        <?php if (count($prodotti) === 0): ?>
            <p>Nessun prodotto disponibile in questo negozio.</p>
        <?php else: ?>
            <form method="POST" action="invia_ordine.php">
                <input type="hidden" name="deposito" value="<?= htmlspecialchars($deposito_selezionato) ?>">
                <table border="1" cellpadding="5" cellspacing="0">
                    <thead>
                        <tr>
                            <th>Prodotto</th>
                            <th>Nome</th>
                            <th>Disponibilità</th>
                            <th>Quantità da acquistare</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($prodotti as $prodotto): ?>
                            <tr>
                                <td><?= htmlspecialchars($prodotto['id']) ?></td>
                                <td><?= htmlspecialchars($prodotto['nome']) ?></td>
                                <td><?= (int)$prodotto['quantita'] ?></td>
                                <td>
                                    <input
                                        type="number"
                                        name="quantita[<?= htmlspecialchars($prodotto['id']) ?>]"
                                        min="0"
                                        max="<?= (int)$prodotto['quantita'] ?>"
                                        value="0"
                                    >
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
                <br>
                <button type="submit">Invia Ordine</button>
            </form>
        <?php endif; ?>
    <?php endif; ?>

    <?php echo '<p><a href="dashboard.php">Torna alla dashboard</a></p>'; ?>

</body>
</html>
