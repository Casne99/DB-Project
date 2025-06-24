<?php
session_start();

if (empty($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true || $_SESSION['user_role'] !== 'cliente') {
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
$punti = 0;
$tessera_esiste = false;
$sconti_disponibili = [];

try {
    // Recupera i negozi attivi
    $stmt = $pdo->prepare("
        SELECT id, orario_apertura, orario_chiusura
        FROM negozi
        WHERE attivo = true
        ORDER BY id
    ");
    $stmt->execute();
    $negozi = $stmt->fetchAll();

    // Recupera il codice fiscale dell'utente
    $stmtCF = $pdo->prepare("SELECT codice_fiscale FROM develop.clienti WHERE login = :login");
    $stmtCF->execute([':login' => $user_email]);
    $codice_fiscale = $stmtCF->fetchColumn();

    if (!$codice_fiscale) {
        throw new Exception("Codice fiscale non trovato per l'utente.");
    }

    // Verifica se esiste una tessera
    $stmtTessera = $pdo->prepare("SELECT punti FROM develop.tessere WHERE proprietario = :cf");
    $stmtTessera->execute([':cf' => $codice_fiscale]);
    $punti_raw = $stmtTessera->fetchColumn();

    if ($punti_raw !== false) {
        $tessera_esiste = true;
        $punti = (int)$punti_raw;
    }

    // Calcola sconti disponibili
    if ($punti >= 100) $sconti_disponibili[] = 5;
    if ($punti >= 200) $sconti_disponibili[] = 15;
    if ($punti >= 300) $sconti_disponibili[] = 30;

    // Recupera i prodotti del deposito selezionato
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
        $prodotti = $stmtProd->fetchAll();
    }

    // Se è stato inviato il form per la richiesta tessera
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['richiedi_tessera']) && $deposito_selezionato && !$tessera_esiste) {
        $stmtInsert = $pdo->prepare("
            INSERT INTO develop.tessere (proprietario, negozio_di_rilascio, punti)
            VALUES (:cf, :negozio, 0)
        ");
        $stmtInsert->execute([
            ':cf' => $codice_fiscale,
            ':negozio' => $deposito_selezionato
        ]);
        header("Location: acquista.php?deposito=" . urlencode($deposito_selezionato));
        exit;
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
            <form method="POST" action="invia_ordine.php" style="display: inline;">
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
                                        style="width: 50px;"
                                    >
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
                <br>

                <?php if (!empty($sconti_disponibili)): ?>
                    <label for="sconto">Applica uno sconto (opzionale):</label>
                    <select name="sconto" id="sconto">
                        <option value="">-- Nessuno --</option>
                        <?php foreach ($sconti_disponibili as $sconto): ?>
                            <option value="<?= $sconto ?>">
                                <?= $sconto ?>% (<?= $sconto === 5 ? "100" : ($sconto === 15 ? "200" : "300") ?> punti)
                            </option>
                        <?php endforeach; ?>
                    </select>
                    <br><br>
                <?php endif; ?>

                <button type="submit" <?= $deposito_selezionato ? '' : 'disabled' ?>>Invia Ordine</button>
            </form>

            <?php if (!$tessera_esiste): ?>
                <form method="POST" action="acquista.php?deposito=<?= urlencode($deposito_selezionato) ?>" style="display:inline;">
                    <input type="hidden" name="richiedi_tessera" value="1">
                    <button type="submit" <?= $deposito_selezionato ? '' : 'disabled' ?>>Richiedi tessera</button>
                </form>
            <?php endif; ?>
        <?php endif; ?>
    <?php endif; ?>

    <p><a href="dashboard.php">Torna alla dashboard</a></p>
</body>
</html>
