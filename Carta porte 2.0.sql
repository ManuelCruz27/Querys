/* 
autor Juan Manuel Cruz Alejandre

Este quiry sirve para los errores
	Origen/Destino por que el vehuculoID es null
	Numero de licencia de conducir es null

	Se tiene que correr en la sucursal 
*/
--*************************************************************************************
/*
	Intruciones 
	Hay que ingresar los documentos de la siguente manera '1234,1234,1234,'.....
	en la variable @DocumentosABuscar
*/
DECLARE @DocumentosABuscar NVARCHAR(MAX) = '209,208,207';


--************************************************************************************
DECLARE @Index INT =1;
DECLARE @TotalRow INT;

Declare @NoDocumento int
DECLARE @Comentario VARCHAR(100)
DECLARE @EmbarqueID int
DECLARE @VehiculoID int
DECLARE @EnvioUsuarioID  int
DECLARE @MonitoreoUsuarioID	int
DECLARE @EmpleadoID int
DECLARE @NoLicencia Varchar(50)
Declare @InfoSucursalID varchar(10)
DECLARE @Timbrado VARCHAR(50) 
DECLARE @Serie VARCHAR(50)
DECLARE @Status INT
DECLARE @Contador INT

DECLARE @TablaTemporal table(NoDocumento int,Serie VARCHAR(50), Comentario VARCHAR(100), EmbarqueID int,
							 VehiculoID int, EnvioUsuario int, MonitoreoUsuario int,
							 EmpleadoID int, NoLicencia VARCHAR(50),InfoSucursal VARCHAR(50),Timbrado int)




--**************************************************************************************
print'Recolectando información de los documentos ......'
INSERT INTO @TablaTemporal (NoDocumento, Serie, Comentario, EmbarqueID, VehiculoID, EnvioUsuario, MonitoreoUsuario, EmpleadoID, NoLicencia, InfoSucursal, Timbrado)
SELECT DISTINCT 
        ENC.no_documento AS NoDocumento,
        ENC.serie AS Serie,
        ENC.comentario,
        CAST(SUBSTRING(ENC.comentario, CHARINDEX('Embarque:', ENC.comentario) + 9, 10) AS int) AS EmbarqueID,
        EmbEnvio.VehiculoId,
        EmbEnvio.UsuarioID AS EnvioUsuario,
        EmbMonitoreo.UsuarioID AS MonitoreoUsuario,
        G.EmpleadoID AS EmpleadoID,
        G.NumLicenciaConducir AS NoLicencia,
        G.InfoSucursalID,
		ENC.Timbrado AS Timbrado
FROM CXCENCABEZADO ENC
JOIN Tra_PYO_AdmonEnvios_Embarques EmbEnvio 
    ON CAST(SUBSTRING(ENC.comentario, CHARINDEX('Embarque:', ENC.comentario) + 9, 10) AS int) = EmbEnvio.EmbarqueID
JOIN Tra_PYO_AdmonEnvios_EmbarquesMonitoreo EmbMonitoreo 
    ON EmbEnvio.EmbarqueID = EmbMonitoreo.EmbarqueID
JOIN MtoCat_SIS_Seguridad_Usuario U 
    ON U.UsuarioID = EmbMonitoreo.UsuarioID
JOIN MtoCat_RH_GestionPersonal_Empleado G 
    ON U.EmpleadoID = G.EmpleadoID
WHERE ENC.no_documento IN(
	SELECT value FROM string_split(@DocumentosABuscar, ','))
  AND ENC.tipo_documento = 't'
  AND ENC.status = 'A'
  AND EmbMonitoreo.MonitoreoID IN (5, 6);


print 'Iniciando las validaciones.'
PRINT '***** NOTAS ******'

select  
		@TotalRow = COUNT(*)
		FROM @TablaTemporal

IF @TotalRow  <=0
BEGIN

	PRINT 'No se encontro información de las facturas' + CHAR(10)+
	'Posiblemente el ClienteID o el numero de facturaID esten mal.'+char(10)
	+'Consulte la información manualmente' 

END 
ELSE 
BEGIN


IF EXISTS(SELECT 1 FROM @TablaTemporal WHERE VehiculoID IS NULL OR NoLicencia IS  NULL and Timbrado = 0)
BEGIN

    -- Verificación de VehiculoID
    IF EXISTS(SELECT 1 FROM @TablaTemporal WHERE VehiculoID IS NULL)
    BEGIN
        PRINT 'El VehiculoID que está NULL.';
        
        SELECT TOP 1 @VehiculoID = VehiculoId
        FROM Tra_PYO_AdmonEnvios_Embarques
        WHERE UsuarioID IN (SELECT EnvioUsuario FROM @TablaTemporal) 
          AND VehiculoId IS NOT NULL
        ORDER BY EmbarqueID DESC;
        
        IF @VehiculoID IS NOT NULL
        BEGIN
            BEGIN TRY
                PRINT 'Se va a modificar el VehiculoID a ' + CAST(@VehiculoID AS VARCHAR(50)) + ' en la tabla Tra_PYO_AdmonEnvios_Embarques con el EmbarqueID ';
                
                UPDATE Tra_PYO_AdmonEnvios_Embarques 
                SET VehiculoId = @VehiculoID 
                WHERE EmbarqueID IN (SELECT EmbarqueID FROM @TablaTemporal);
                
                UPDATE @TablaTemporal 
                SET VehiculoID = @VehiculoID;
            END TRY
            BEGIN CATCH
                PRINT 'Error al realizar el update en el VehiculoID: ' + ERROR_MESSAGE();
            END CATCH;
        END
    END

	  -- Verificación del NoLicencia
    IF EXISTS(SELECT 1 FROM @TablaTemporal WHERE NoLicencia IS  NULL)
    BEGIN
        PRINT 'El número de licencia es NULL.';

        SELECT TOP 1
            @NoLicencia = g.NumLicenciaConducir,
            @MonitoreoUsuarioID = s.UsuarioID
        FROM MtoCat_SIS_Seguridad_Usuario s
        JOIN MtoCat_RH_GestionPersonal_Empleado g ON s.EmpleadoID = g.EmpleadoID
        WHERE g.PuestoID IN (78,79,241)
          AND g.InfoSucursalID IN (SELECT InfoSucursal FROM @TablaTemporal)
          AND g.NumLicenciaConducir IS NOT NULL;

        IF @NoLicencia IS NOT NULL
        BEGIN
            BEGIN TRY
                PRINT 'Se va a hacer el update en la tabla Tra_PYO_AdmonEnvios_EmbarquesMonitoreo porque el número de licencia es NULL.';
                
                UPDATE [dbo].[Tra_PYO_AdmonEnvios_EmbarquesMonitoreo]
                SET UsuarioID = @MonitoreoUsuarioID
                WHERE EmbarqueID in(SELECT EmbarqueID FROM @TablaTemporal) AND MonitoreoID IN (5,6);
       	   
				update @TablaTemporal set 
				NoLicencia  =  g.NumLicenciaConducir,
				@MonitoreoUsuarioID = s.UsuarioID
				FROM MtoCat_SIS_Seguridad_Usuario s
				JOIN MtoCat_RH_GestionPersonal_Empleado g ON s.EmpleadoID = g.EmpleadoID
				WHERE s.UsuarioID = @MonitoreoUsuarioID

            END TRY
            BEGIN CATCH
                PRINT 'Error al realizar el update de numero de licencia: ' + ERROR_MESSAGE();
            END CATCH;
        END
        ELSE
        BEGIN
            PRINT 'Falló el proceso de selección de usuario Monitoreo :-(';
        END
    END


END --FIN de la validacion VehiculoID is null 
ELSE IF EXISTS(SELECT Timbrado FROM @TablaTemporal where Timbrado = 1 )-- @VehiculoID is not null and @NoLicencia is not null
BEGIN 
	PRINT 'Los documentos ya estan timbrados' 
END 
ELSE if EXISTS(SELECT VehiculoID,NoLicencia FROM @TablaTemporal where VehiculoID is not null and NoLicencia is not null)-- @VehiculoID is not null and @NoLicencia is not null
BEGIN
	print 'Los campos VehiculoID y Numero de licencia no son nulos ;-)'
END 
else 
begin
	print 'Fallo el programa ' +char(10)+char(15)+
		  'Algo esta fuera de lo normal. :O'
end 
end
Print '*****************************************************************************************'

-- Impresión de los resultados
PRINT CHAR(13) + CHAR(10) + 'Cartas portes seleccionadas:';
PRINT '--------------------------------------------------------------------------------------------------------------------';

WHILE @Index <= @TotalRow
BEGIN
	SELECT 

		@NoDocumento = NoDocumento,
		@Serie = Serie,
		@Comentario = Comentario,
		@EmbarqueID = EmbarqueID,
		@VehiculoID = VehiculoID,
		@EnvioUsuarioID = EnvioUsuario,
		@MonitoreoUsuarioID = MonitoreoUsuario,
        @EmpleadoID = EmpleadoID,
        @NoLicencia = NoLicencia,
        @InfoSucursalID = InfoSucursal,
        @Timbrado = Timbrado

	FROM 
	(SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum, *
	FROM @TablaTemporal) AS Temp
	WHERE
	RowNum = @Index;

	PRINT 'Información del Embarque: ' + CHAR(10) +
          ' | NoDocumento: ' + CAST(@NoDocumento AS VARCHAR(50)) + 
          ' | Serie: ' + CAST(@Serie AS VARCHAR(20)) + 
          ' | Comentario: ' + CAST(@Comentario AS VARCHAR(50)) + 
          ' | Timbrado: ' + CAST(@Timbrado AS VARCHAR(10)) + 
          ' | EmbarqueID: ' + CAST(@EmbarqueID AS VARCHAR(50)) + 
          ' | VehiculoID: ' + ISNULL(CAST(@VehiculoID AS VARCHAR(50)), 'N/A') + CHAR(10) + CHAR(15) +
          ' | EnvioUsuarioID: ' + CAST(@EnvioUsuarioID AS VARCHAR(50)) + 
          ' | MonitoreoUsuarioID: ' + CAST(@MonitoreoUsuarioID AS VARCHAR(50)) + 
          ' | EmpleadoID: ' + CAST(@EmpleadoID AS VARCHAR(50)) + 
          ' | NoLicencia: ' + ISNULL(@NoLicencia, 'N/A') + 
          ' | InfoSucursalID: ' + CAST(@InfoSucursalID AS VARCHAR(50));

		   PRINT '--------------------------------------------------------------------------------------------------------------------';

		   SET @Index = @Index + 1;

END


PRINT '****** Fin del programa ***********';

