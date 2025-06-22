<?php
session_start();
if (empty($_SESSION['logged_in']) || $_SESSION['user_role'] !== 'manager') {
    header('Location: login.php');
    exit;
}
?>

<?php if (isset($_GET['success'])): ?>
    <p style="color: green;">Prodotto aggiunto con successo.</p>
<?php endif; ?>

<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <title>Aggiungi Prodotto</title>
</head>
<body>
    <h1>Aggiungi Nuovo Prodotto</h1>

    <?php if (isset($_GET['error'])): ?>
        <p style="color: red;">Errore durante l'aggiunta del prodotto. Verificare i dati.</p>
    <?php endif; ?>

    <form action="processa_aggiunta_prodotto.php" method="POST">
        <div>
            <label for="id">ID Prodotto (7 caratteri):</label><br>
            <input type="text" id="id" name="id" maxlength="7" required>
        </div><br>

        <div>
            <label for="nome">Nome:</label><br>
            <input type="text" id="nome" name="nome" required>
        </div><br>

        <div>
            <label for="descrizione">Descrizione:</label><br>
            <textarea id="descrizione" name="descrizione" rows="4" cols="50" required></textarea>
        </div><br>

        <button type="submit">Aggiungi Prodotto</button>
    </form>

    <p><a href="prodotti.php">Torna alla Gestione Prodotti</a></p>
</body>
</html>
