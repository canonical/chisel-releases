<?php
$pharFile = 'test.phar';

try {
    $phar = new Phar($pharFile);
    foreach (new RecursiveIteratorIterator($phar) as $file) {
        echo $file->getPathname() . "\n";
    }
} catch (Exception $e) {
    echo "Failed to open PHAR: " . $e->getMessage();
}
