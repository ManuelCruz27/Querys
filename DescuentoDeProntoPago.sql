/*
	Descuento de pronto pago 
	Autor: Juan Manuel Cruz Alejandre 

	Este Query sirve para ponerle el descuento de pronto pago a las facturas 
	hay que ingresar nomas los siguentes datos:
	las factraID  que desea aplicarles el descuento 
	Los clienteID de las facturas 
	de la siguiente manera en su variable correspondiente 

*/

/*
   	Intruciones 
	Hay que ingresar los documentos de la siguente manera '1234,1234,1234,'.....
	en la variable @BuscarClientes y en @BuscarFacturas
*/

DECLARE @BuscarClientes VARCHAR(MAX)='501209'

DECLARE @BuscarFacturas VARCHAR(MAX)='157286,157341,158281';


DECLARE @Index INT = 1;
DECLARE @TotalRows INT;



--*************************************************************************************DECLARE @Contador INT
DECLARE @TablaTemporal TABLE (FacturaID int ,PedidoID int, ClienteID int, PCID int, TipoProntoPagoID int,
							  DescuentoPagoPuntual int, Nombre VARCHAR(59),Fecha DATETIME,StatusID INT, 
							  TipoPortafolioDescuentoID int, PorcentajeProntoPago int, TipoDescuento varchar(50), TipoDescuentoProntoPagoID int) 

DECLARE @FacturaID int ,@PedidoID int, @ClienteID int, @PCID int, @TipoProntoPagoID int,
		@DescuentoPagoPuntual int, @Nombre VARCHAR(59),@Fecha DATETIME,@StatusID INT, 
		@TipoPortafolioDescuentoID int, @PorcentajeProntoPago int, @TipoDescuento varchar(50), @TipoDescuentoProntoPagoID int;


print 'Se van a insertar los valores en la tabla temporal @TablaTemporal para hacer las validaciones '
INSERT INTO @TablaTemporal (FacturaID,PedidoID,ClienteID, PCID,TipoProntoPagoID,DescuentoPagoPuntual,Nombre,Fecha,StatusID, TipoPortafolioDescuentoID, PorcentajeProntoPago, TipoDescuento,TipoDescuentoProntoPagoID)
SELECT f.FacturaID,p.PedidoID,p.ClienteID, p.PCID, isnull((p.TipoProntoPagoID),0), p.DescuentoPagoPuntual,
f.Nombre,f.Fecha,f.Status, isnull((c.TipoPortafolioDescuentoID),0), c.PorcentajeProntoPago, tp.TipoDescuento, isnull((c.TipoDescuentoProntoPagoID),0)
FROM Tra_VYM_Ventas_Factura f
JOIN Tra_VYM_Ventas_Pedido p ON f.PedidoID = p.PedidoID 
join vym.mtotra_pc2020_clientelistaspreciosregion c on p.ClienteID = c.ClienteID
JOIN VYM.MtoCat_PC2020_TipoDescuentoProntoPago tp on c.TipoDescuentoProntoPagoID = tp.Id
WHERE f.FacturaID IN(SELECT value FROM string_split(@BuscarFacturas,',') ) 
	AND p.ClienteID IN(SELECT value FROM string_split(@BuscarClientes, ',') )
	ORDER BY p.ClienteID 

select @TotalRows = COUNT(*)  from @TablaTemporal
	Print '********************************************'
	print '****** Nota *****'
IF @TotalRows  <=0
BEGIN

	PRINT 'No se encontro información de las facturas' + CHAR(10)+
	'Posiblemente el ClienteID o el numero de facturaID esten mal.'+char(10)
	+'Consulte la información manualmente' 

END 
ELSE 
BEGIN

IF EXISTS (SELECT 1 FROM @TablaTemporal WHERE PCID = 3 and StatusID in(1,4))
BEGIN
	IF EXISTS(select 1 from @TablaTemporal where PorcentajeProntoPago in(10,5))
	BEGIN
		IF EXISTS (SELECT 1 FROM @TablaTemporal WHERE DescuentoPagoPuntual = 0)
		BEGIN
			IF EXISTS(SELECT 1 FROM @TablaTemporal WHERE  TipoDescuentoProntoPagoID = 2 AND TipoDescuento ='Nota de credito')
			BEGIN
				IF EXISTS(SELECT 1 FROM Tra_VYM_Ventas_Pedido WHERE ClienteID IN(SELECT ClienteID FROM @TablaTemporal))
				BEGIN
					IF EXISTS(SELECT 1 FROM @TablaTemporal WHERE TipoProntoPagoID in(0,1) )
					BEGIN
						BEGIN TRY
						PRINT 'Se le va a realizar el Update al campo "TipoProntoPagoID" en la tabla "Tra_VYM_Ventas_Pedido" por que es igual a  1 y se le va a cambiar a 2'
	
						update Tra_VYM_Ventas_Pedido set TipoProntoPagoID = 2 
						where PedidoID in(SELECT PedidoID FROM @TablaTemporal where TipoProntoPagoID in(1,0)  AND ClienteID = Tra_VYM_Ventas_Pedido.ClienteID) 
						
						END TRY
						BEGIN CATCH
							PRINT 'Error al realizar el update en el campo TipoProntoPagoID: ' + ERROR_MESSAGE();
							
						END CATCH

					END
					ELSE IF EXISTS(SELECT 1 FROM @TablaTemporal WHERE TipoProntoPagoID in(2) )
					BEGIN
						PRINT 'La factura ya cuenta con el TipoProntoPagoID configurado'
							
					END
					ELSE
					BEGIN
						PRINT 'holi'
							
					END
				END
				ELSE
				BEGIN
					PRINT 'El ClienteID no coincide.'
						
				END
			END
			ELSE 
			BEGIN
				PRINT 'La configuracion de "TipoDescuentoProntoPagoID" no es el ID(2) de "Nota de credito".' + CHAR(10)
				+ 'Por favor de validar con prissing.'
			END
		END -- FIN IF EXISTS (SELECT 1 FROM @TablaTemporal WHERE DescuentoPagoPuntual = 0) 
		ELSE 
		BEGIN
			PRINT 'La factura ya tiene aplicado el "DescuentoPagoPuntual". '
		END
	END --FIN IF EXISTS(select 1 from @TablaTemporal where PorcentajeProntoPago in(10,5))
	ELSE
	BEGIN
		PRINT 'La factura no tiene configurado el "PorCentajeProntoPago" ' + char(13)+char(10) + 
			   'hay que revisarlo con prissing para que configuren el cliente con su descuento.'
	END

END --FIN EXISTS (SELECT 1 FROM @TablaTemporal WHERE PCID = 3 and StatusID in(1,4))
ELSE IF	EXISTS(SELECT 1 FROM @TablaTemporal WHERE StatusID in(0,3))
BEGIN
	PRINT 'La factura posiblemente este cancelada o tenga un estatus no valido. '
END --IF	EXISTS(SELECT 1 FROM @TablaTemporal WHERE StatusID in(1,4))
ELSE IF EXISTS (SELECT 1 FROM @TablaTemporal WHERE PCID != 3)
BEGIN
	PRINT 'El PCID es diferente a 3.';
END 

END

Print '********************************************'


print  char(13)+char(10) + 'Se van actualizar los datos en la tabla temporal (@TablaTemporal)'
update t
set
    t.TipoProntoPagoID = ISNULL(p.TipoProntoPagoID, 0)
FROM  @TablaTemporal t
join Tra_VYM_Ventas_Factura f on t.FacturaID = f.FacturaID
JOIN Tra_VYM_Ventas_Pedido p ON f.PedidoID = p.PedidoID 
join vym.mtotra_pc2020_clientelistaspreciosregion c on p.ClienteID = c.ClienteID
JOIN VYM.MtoCat_PC2020_TipoDescuentoProntoPago tp on c.TipoDescuentoProntoPagoID = tp.Id
WHERE f.FacturaID IN (SELECT value FROM string_split(@BuscarFacturas,',') )
AND p.ClienteID IN(SELECT value FROM string_split(@BuscarClientes, ',') )



PRINT char(13)+char(10)+'Facturas seleccionadas:';
PRINT '--------------------------------------------------------------------------------------------------------------------';
    
WHILE @Index <= @TotalRows
BEGIN
	SELECT
	@facturaID = FacturaID,
	@PedidoID = PedidoID,
	@ClienteID = ClienteID,
	@PCID = PCID,
	@TipoProntoPagoID = TipoProntoPagoID,
	@DescuentoPagoPuntual = DescuentoPagoPuntual,
	@Nombre = Nombre,
	@Fecha = Fecha, 
	@StatusID = StatusID, 
	@TipoPortafolioDescuentoID = TipoPortafolioDescuentoID,
	@PorcentajeProntoPago = PorcentajeProntoPago,
	@TipoDescuento = TipoDescuento,
	@TipoDescuentoProntoPagoID = TipoDescuentoProntoPagoID

	FROM
	(SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum, *
	FROM @TablaTemporal) AS Temp
	WHERE RowNum = @Index;

	PRINT 'Información de la factura: '+'FacturaID: ' + CAST(@FacturaID AS VARCHAR(10))+', ' +'Nombre: ' + CAST(@Nombre as varchar(25))+', ' +'Fecha: ' + CAST(@Fecha AS VARCHAR(25))+', '+'Estatus: ' +CAST(@StatusID AS VARCHAR(10)) + CHAR(13) + CHAR(10) +
          'Información del pedido: ' + ' PedidoID: ' + CAST(@PedidoID AS VARCHAR(10)) + ', ' + 'ClienteID: ' + CAST(@ClienteID AS VARCHAR(10)) +', '+ 'PCID: '+ CAST(@PCID as varchar(10)) +', '+ 'TipoProntoPagoID: '+CAST(@TipoProntoPagoID AS VARCHAR (10))+', '+'DescuentoPagoPuntual: '+ CAST(@DescuentoPagoPuntual AS VARCHAR(20)) +char(13)+char(10)+
		   'Información de la configuracipon del cliente: '+'TipoDescuentoProntoPagoID: ' + cast(@TipoDescuentoProntoPagoID AS VARCHAR(50)) + ', '+ 'TipoDescuento: ' + cast(@TipoDescuento as varchar(50))+', '+ CHAR(13) + CHAR(10) +'PorcentajeProntoPago: '+CAST(@PorcentajeProntoPago AS VARCHAR(10)) +', '+'TipoPortafolioDescuentoID: ' + CAST(@TipoPortafolioDescuentoID AS VARCHAR (10));
		   PRINT '--------------------------------------------------------------------------------------------------------------------';
	SET @Index = @Index +1;

END

PRINT '****** Fin del programa ***********'