<?php

function get_user_role(PDO $pdo, string $login): ?string
{
    $pdo->exec("SET search_path = develop");

    $stmt = $pdo->prepare("SELECT 1 FROM develop.clienti WHERE login = :login");
    $stmt->execute(['login' => $login]);
    if ($stmt->fetch()) {
        return 'cliente';
    }

    $stmt = $pdo->prepare("SELECT 1 FROM develop.manager WHERE login = :login");
    $stmt->execute(['login' => $login]);
    if ($stmt->fetch()) {
        return 'manager';
    }

    return null;
}
