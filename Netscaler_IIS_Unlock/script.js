document.getElementById("usernameForm").addEventListener("submit", function(event) {
    event.preventDefault(); // Prevent default form submission

    var username = document.getElementById("username").value;

    // Send username to backend using fetch
    fetch("/executeScript", {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({ username: username })
    })
    .then(response => {
        if (response.ok) {
            // Handle success
            console.log("Script executed successfully");
        } else {
            // Handle error
            console.error("Error executing script");
        }
    })
    .catch(error => {
        console.error("Error:", error);
    });
});
