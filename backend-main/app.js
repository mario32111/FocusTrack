var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var cors = require('cors');

// Importar rutas
var indexRouter = require('./routes/index');
var empresasRouter = require('./routes/empresas');
var usuariosRouter = require('./routes/usuarios');
var contactosEmergenciaRouter = require('./routes/contactosEmergencia');
var conductoresRouter = require('./routes/conductores');
var viajesRouter = require('./routes/viajes');
var alertasRouter = require('./routes/alertas');
var dispositivosRouter = require('./routes/dispositivos');
var mqttRouter = require('./routes/mqtt');

var app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');

// Middlewares
app.use(cors());
app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

// Registrar rutas
app.use('/', indexRouter);
app.use('/empresas', empresasRouter);
app.use('/usuarios', usuariosRouter);
app.use('/contactos-emergencia', contactosEmergenciaRouter);
app.use('/conductores', conductoresRouter);
app.use('/viajes', viajesRouter);
app.use('/alertas', alertasRouter);
app.use('/dispositivos', dispositivosRouter);
app.use('/mqtt', mqttRouter);

// catch 404 and forward to error handler
app.use(function (req, res, next) {
  next(createError(404));
});

// error handler
app.use(function (err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.json({ error: err.message });
});

module.exports = app;
