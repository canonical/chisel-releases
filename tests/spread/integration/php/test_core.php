<?php
$errors = [];
$name = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = trim($_POST['name'] ?? '');

    if ($name === '') {
        $errors[] = "Name is required.";
    }

    if (!$errors) {
        echo "Submitted name: " . htmlspecialchars($name);
        exit;
    }
}
?>

<form method="post">
    Name: <input name="name" value="<?= htmlspecialchars($name) ?>">
    <input type="submit" value="Submit">
</form>

<?php
foreach ($errors as $error) {
    echo "<p style='color:red;'>$error</p>";
}
