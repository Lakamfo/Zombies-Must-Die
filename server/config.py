ADMIN_TEMPLATE = '''
<!doctype html>
<title>Admin Panel</title>
<style>
    .modal {
        display: none; 
        position: fixed;
        z-index: 1; 
        left: 0;
        top: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(0,0,0,0.4); 
        padding-top: 60px;
        text-align: center;
    }

    .modal-content {
        background-color: #fefefe;
        margin: 5% auto;
        padding: 20px;
        border: 1px solid #888;
        width: 80%;
        max-width: 300px;
        border-radius: 5px;
    }

    body {
        font-family: Arial, sans-serif;
        background-color: #f4f7f6;
        color: #333;
        margin: 0;
        padding: 0;
    }

    h1, h2 {
        text-align: center;
        color: #2c3e50;
    }

    .container {
        width: 80%;
        margin: 20px auto;
        background-color: #ffffff;
        padding: 20px;
        border-radius: 8px;
        box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
    }

    table {
        width: 100%;
        margin: 20px 0;
        border-collapse: collapse;
    }

    table th, table td {
        padding: 10px;
        text-align: left;
        border-bottom: 1px solid #ddd;
    }

    table th {
        background-color: #34495e;
        color: #fff;
    }

    table tr:nth-child(even) {
        background-color: #f9f9f9;
    }

    table tr:hover {
        background-color: #f1f1f1;
    }

    .button {
        background-color: #3498db;
        color: white;
        border: none;
        padding: 10px 20px;
        font-size: 16px;
        cursor: pointer;
        border-radius: 5px;
        text-align: center;
        text-decoration: none;
    }

    .form-container {
        display: flex;
        justify-content: center;
        align-items: center;
        gap: 10px;
        margin-bottom: 30px;
    }

    .form-container input {
        padding: 10px;
        font-size: 16px;
        border-radius: 5px;
        border: 1px solid #ddd;
    }

    .form-container button {
        background-color: #2ecc71;
        border: none;
        color: white;
        padding: 10px 20px;
        font-size: 16px;
        cursor: pointer;
        border-radius: 5px;
    }

    .form-container button:hover {
        background-color: #27ae60;
    }

    .button {
        background-color: #3498db;
        color: white;
        border: none;
        padding: 10px 20px;
        font-size: 16px;
        cursor: pointer;
        border-radius: 5px;
        text-align: center;
        text-decoration: none;
    }

    .button:hover {
        background-color: #2980b9;
    }

    .cancel-button {
        background-color: #e74c3c;
    }

    .cancel-button:hover {
        background-color: #c0392b;
    }
</style>

<div class="container">
    <h2>Game Version: {{ version }}</h2>

    <form method="POST" action="{{ admin_url }}/change_game_version" class="form-container">
        <input type="text" name="new_version" placeholder="Enter new version" required>
        <button type="submit">Change Version</button>
    </form>

    <form method="POST" action="{{ admin_url }}/force_update_leaderboard" style="display:inline">
        <button type="submit" class="button">Force Update Leaderboard</button>
    </form>

    <h1>Players</h1>
    <table>
        <tr><th>ID</th><th>Login</th><th>Actions</th></tr>
        {% for player in players %}
        <tr>
            <td>{{ player[0] }}</td>
            <td>{{ player[1] }}</td>
            <td>
                <button type="button" class="button" onclick="confirmDelete('{{ admin_url }}/delete_player/{{ player[0] }}')">Delete</button>
            </td>
        </tr>
        {% endfor %}
    </table>

    <h1>Records</h1>
    <table>
        <tr><th>ID</th><th>Player ID</th><th>Score</th><th>Actions</th></tr>
        {% for record in records %}
        <tr>
            <td>{{ record[0] }}</td>
            <td>{{ record[1] }}</td>
            <td>{{ record[3] }}</td>
            <td>
                <button type="button" class="button" 
                    onclick="confirmDelete('{{ admin_url }}/delete_record/{{ record[0] }}')">
                    Delete
                </button>
            </td>
        </tr>
        {% endfor %}
    </table>
</div>  

<!-- Modal confirmation window -->
<div id="confirmModal" class="modal">
    <div class="modal-content">
        <h3>Are you sure you want to delete this?</h3>
        <form id="deleteForm" method="POST">
            <button type="submit" class="button">Confirm</button>
            <button type="button" class="cancel-button" onclick="closeModal()">Cancel</button>
        </form>
    </div>
</div>

<script>
    function confirmDelete(url) {
        document.getElementById("confirmModal").style.display = "block";

        document.getElementById("deleteForm").action = url;
    }

    function closeModal() {
        document.getElementById("confirmModal").style.display = "none";
    }

    window.onclick = function(event) {
        if (event.target == document.getElementById("confirmModal")) {
            closeModal();
        }
    }
</script>
'''

