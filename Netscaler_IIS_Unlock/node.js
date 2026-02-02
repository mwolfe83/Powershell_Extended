const express = require('express');
const bodyParser = require('body-parser');
const { exec } = require('child_process');

const app = express();
const port = 3000;

app.use(bodyParser.json());

app.post('/executeScript', (req, res) => {
    const username = req.body.username;

    // Execute PowerShell script with the provided username
    exec(`powershell.exe -File "C:\\scripts\\unlockAAA.ps1" -Username "${username}"`, (error, stdout, stderr) => {
        if (error) {
            console.error('Error executing script:', error);
            res.status(500).send('Error executing script');
            return;
        }
        console.log('Script executed successfully');
        res.sendStatus(200);
    });
});

app.listen(port, () => {
    console.log(`Server is listening at http://localhost:${port}`);
});
