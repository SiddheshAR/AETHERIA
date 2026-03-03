
const express = require('express');
const {Pool} = require('pg');

const app = express();
const PORT = 3000;

const pool = new Pool({
        user:'appuser',
host:'localhost',
database:'myapp',
password:'apppassword',
port:5432,
});

app.get('/',(req,res)=>{
        res.send('API is running!')
})

app.get('/users',async(req,res)=>{
        try{
        const result = await pool.query('SELECT * FROM users');
        res.json(result.rows);
}catch(err){
        console.log(err);
        res.status(500).json({error:'Database error'})
}
})


app.listen(PORT,()=>{
        console.log(`Server is running on port ${PORT}`);
})
