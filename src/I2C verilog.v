`timescale 1ns / 1ps

module i2cMaster(
	input       CLK,            //Тактовая частота
	input       [57:0]  M2S,             //Запрос мастера к клиенту {RQ,RW,DI,Addr}
    output reg  [32:0]  S2M = 0,         //Ответ клиента мастеру  {ACK,DO}
	output reg          Global_reset = 0,    // программый сброс наружу
	inout SCL,
	inout SDA
    );

    //================================== M2S интерфейс блока =================================================//
	wire          M2S_RQ   = M2S[57];
	wire          M2S_RW   = M2S[56];
	wire  [23:0]  M2S_Addr = M2S[23:0];  
	wire  [31:0]  M2S_Data = M2S[55:24];

	reg           S2M_ACK  = 0;
	reg   [31:0]  S2M_Data = 0;	
	
	reg [31:0]  time_ms = 0;
	reg [31:0]  time_mks = 0;
	reg [9:0]   tick_mks = 0;
	reg [19:0]  tick_ms = 0;
	
    //================================= Регистры для I2C =================================//
    parameter SPD = 250;
	reg         START = 0; // Сигнал старта
    reg         STOP  = 0; 
    reg [7:0]   STATE = 0; 
    reg [7:0]   NEXT  = 0;
    reg [7:0]   SEND_BYTE = 0;
    reg [31:0]  WRITE_BYTE = 0;
    reg [7:0]   byte_to_send = 0;    
    reg [4:0]   bit_sending = 0;
    
    reg         SDA_i = 1;         
    reg         SDA_r = 1; 
    
    reg         SCL_r = 1;
    reg         SCL_i = 1; 
    
    reg [7:0]   ERROR = 0;
    reg         ACK = 0;

    reg [15:0]  count = 0;
    //========================================================================================================//
    
    reg                 flag             = 0;
    reg                 flagTact         = 0;
    reg [7:0]           newTact          = 1;    // сколько сделать дополнительных тактов
    reg         [3:0]   currentTact      = 0;
    //============================================== Для теста ==============================================//
    reg         [5:0]  test             = 2;    // Используется для задержки EN в тесте (чтоб EN не сразу возвращалась в норму)
        // формат iij : ii - адрес, j - количество пакетов
    reg         [1:0]  RW = 0;
    reg         [4:0]  pack_sending = 0;
    reg         [3:0]  NUM_PACK = 0;
    //=======================================================================================================// 
    reg [2:0]  PACK_RECEIVED    = 1;    //сколько хотим получить
    reg [2:0]  pack_rec         = 0;    //сколько получ
    reg [31:0] READ_BYTE        = 0;
    reg [7:0]  RECEIVE_BYTE     = 0;
    reg [4:0]  bit_received     = 0;
    reg [7:0]  SLAVE_ADDR_READ  = 0;
    reg [4:0]  ADDR_CELL        = 04;
    //=======================================================================================================//
    reg [23:0] PACK       = 0;  // PACK сосотит из 3 переменных :
      
    reg [7:0]  SLAVE_ADDR = 0;  // Адрес устройства
    reg [7:0]  CELL_ADDR  = 0;  // Адрес ячейки
    reg [7:0]  PACKAGE    = 0;  // Данные. При записи тут будут данные для устройства. При чтении - прочитанное число
    reg [4:0]  recBit     = 0;
    //=======================================================================================================//
    
    
    
    assign SDA = SDA_r ? 1'bz : 0;
    assign SCL = SCL_r ? 1'bz : 0;
    
       
       
       
   reg [5:0] numOfOperation = 0;
    //*******************************************************************************************************//   
	//********************************************** СуперЦикл **********************************************//	

	
	always @(posedge CLK) begin 	
			S2M_ACK <= M2S_RQ;
			S2M     <= {S2M_ACK,S2M_Data};
			if (Global_reset == 1)
				Global_reset <= 0;
            if (tick_mks < 100)                 // 1 / 10 секунды
                begin
                    tick_mks <= tick_mks + 1;
                end
            else
                begin
                    tick_mks <= 0;
                    time_mks <= time_mks + 1;
                end
            if (tick_ms < 100000)               // 1 / 10 секунды    
                begin
                    tick_ms <= tick_ms + 1;
                end
            else
                begin
                    tick_ms <= 0;
                    time_ms <= time_ms + 1;
                end
                
            //%%%%%%%%%%%%%%%%%%%%%%%%%%%% I2C %%%%%%%%%%%%%%%%%%%%%%%%%%%//
            SDA_i <= SDA;
            SCL_i <= SCL;    
            SCL_r <= SCL_r;       
            
            //::::::::::::::::::::::::: Сам автомат ::::::::::::::::::::::::://
            case(STATE)
                0: begin
                    //Простой
                    numOfOperation <= 0;
                end                
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ХАБ %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
                19: // 1 - чтение           0 - запись
                    begin
                        if (SLAVE_ADDR[0] == 0) //&&&&&&&&&&&&&&&&
                            begin
                                RW <= 1;
                                case (numOfOperation)
                                    //==============================================//
                                    0:  //START
                                        begin
                                            STATE <= 23;  
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                    1:  // адрес устройства
                                        begin
                                            STATE <= 21;
                                            byte_to_send <= SLAVE_ADDR;
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                    2:  // адрес ячейки
                                        begin
                                            STATE <= 21;
                                            byte_to_send <= CELL_ADDR;
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                    3:  // данные
                                        begin
                                            STATE <= 21;
                                            byte_to_send <= PACKAGE;
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    4:  //STOP
                                        begin   
                                            STATE <= 20;
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                    5:  //STOP
                                        begin   
                                            STATE <= 40;
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                endcase
                            end
                        else 
                            begin
                            RW <=2;
                                case (numOfOperation)
                                    //==============================================//
                                    0:  //START
                                        begin
                                            STATE <= 23;    
                                            
                                            numOfOperation <= numOfOperation + 1;                      
                                        end
                                    //==============================================//
                                    1:  //Адрес устройства
                                        begin   
                                            STATE <= 21;                  
                                            byte_to_send <= SLAVE_ADDR;
                                            byte_to_send[0] <= 0;
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                    2:  //Адрес ячейки
                                        begin   
                                            STATE <= 21;                                            
                                            byte_to_send <= CELL_ADDR;
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                    3:  //Повторный START
                                        begin   
                                            STATE <= 40;   
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                     //==============================================//
                                    4:  //Повторный START
                                        begin   
                                            STATE <= 23;   
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                    5:  //Адрес устройства
                                        begin   
                                            STATE <= 21;            
                                            byte_to_send <= SLAVE_ADDR;
                                            byte_to_send[0] <= 1;             
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                    6:  //Чтение
                                        begin                                               
                                            STATE <= 22;             
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                    7:  //STOP
                                        begin   
                                            STATE <= 20;
                                            
                                            numOfOperation <= numOfOperation + 1;
                                        end
                                    //==============================================//
                                endcase
                            end
                        
                    end
                   
                //$$$$$$$$$$$$$$$$$$ Команды $$$$$$$$$$$$$$$$$$//
                //=================================//
                20:
                    begin   //STOP                             
                        numOfOperation <= 0;
                        count = SPD;
                        
                        STATE <= 210;
                    end
                //=================================//
                21:
                    begin   //WRITE
                        //### Обнуление записи ###//                        
                        bit_sending <= 0;
                        pack_sending <= 0;
                        ACK <= 0;
                        flag <= 0;
                        //########################//
                         
                        STATE <= 102;
                    end
                //=================================//
                22: 
                    begin   //READ
                        //### Обнуление чтения ###//
                        RECEIVE_BYTE <= 0;
                        bit_received <= 0;
                        recBit <= 7;
                        //########################//
                        
                        STATE <= 62;
                    end
                //=================================//
                23:
                    begin //START         
                        STATE <= 200;
                    end
                //=================================//
                //$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$// 
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
                
          
       
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ЗАПИСЬ %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
                102:
                    begin
                        if (bit_sending == 8)
                            begin
                                STATE <= 110;       //++++ ВЫХОД ++++//
                                SDA_r <= 1 ;
                            end                        
                        else 
                            begin
                                count <= SPD/2;
                                SCL_r <= 0;    
                                STATE <= 103;                                
                            end
                               
                    end
                103:
                    begin
                        if (count == 0)
                            begin
                                SDA_r <= byte_to_send[7];
                                byte_to_send <= {byte_to_send[6:0], 1'b0};
                                
                                count <= SPD/2;
                                STATE <= 104;
                            end
                        else
                            begin
                                count = count - 1;
                            end
                    end
                104:
                    begin
                        if (count == 0)
                            begin
                                SCL_r <= 1;
                                count <= SPD;
                                STATE <= 105;
                            end
                        else
                            count <= count -1;    
                    end
                105:
                    begin
                        if (count == 0)   
                            begin                     
                                bit_sending <= bit_sending + 1;                                
                                STATE <= 102;     
                            end 
                        else 
                            count <= count - 1;
                    end
                    
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
                
                40: //конечный такт
                    begin                        
                        SDA_r <= 0;
                        SCL_r <= 0;
                        count <= SPD;
                        STATE <= 41;     
                    end
                41:
                    begin
                        if (count == 0)
                            begin
                                SDA_r <= 1;
                                SCL_r <= 1;
                                STATE <= 19;
                            end
                        else
                            count <= count-1;    
                    end
               

                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ЧТЕНИЕ %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
                62:
                    begin 
                        if (bit_received == 8)
                            begin
                                STATE <= 110;        //++++ ВЫХОД ++++//
                                SDA_r <= 1 ;
                                pack_rec <= pack_rec + 1;
                            end                        
                        else 
                            begin
                                count <= SPD/2;
                                SCL_r <= 0;    
                                STATE <= 63;                                
                            end
                    end
                    
                63:
                    begin
                        if (count == 0)
                            begin
                                RECEIVE_BYTE[recBit] <= SDA_i;
                                recBit <= recBit - 1;
                                count <= SPD/2;
                                STATE <= 64;
                            end
                        else
                            begin
                                count = count - 1;
                            end
                    end
                64:
                    begin
                        if (count == 0)
                            begin
                                SCL_r <= 1;
                                count <= SPD;
                                STATE <= 65;
                            end
                        else
                            count <= count -1;    
                    end
                65:
                    begin
                        if (count == 0)   
                            begin                     
                                bit_received <= bit_received+1;                               
                                STATE <= 62;     
                            end 
                        else 
                            count <= count - 1;
                    end     
           
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
                
                
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Холостые %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
                110:
                    begin
                        if (currentTact == newTact)
                            begin
                                    currentTact <= 0;
                                    SCL_r <= 1;
                                    STATE <= 19;        //++++ ВЫХОД ++++//
                            end
                        else 
                            begin
                                SCL_r <= 0;
                                count <= SPD/2;
                                STATE <= 111;
                            end  
                    end
                111:   
                    begin   
                        if (count == 0)
                            begin     
                                if (flag == 0 )                                                        
                                    ACK <= ~SDA_i;
                                flag <= 1;  
                                count <= SPD/2;
                                STATE <= 112;
                            end
                        else
                            begin
                                count <= count-1;
                            end                                         
                    end                  
                112:
                    begin
                         if (count == 0)
                            begin
                            if (ACK == 1)
                                begin                         
                                    SCL_r <= 1;
                                    count <= SPD;
                                    STATE <= 113;
                                end
                            else
                                begin
                                    STATE <= 210;
                                end
                                
                            end
                        else
                            begin
                                count <= count-1;
                            end         
                    end  
                113:   
                    begin
                        if (count == 0)
                            begin
                                count = SPD/2;    
                                currentTact <= currentTact + 1; 
                                STATE <= 110;
                            end
                        else
                            begin
                                count <= count-1;
                            end       
                    end  
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
                    
                    
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% START %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//     
                200: // START
                     begin
                        START <= 0;
                        SDA_r <= 1;
                        SCL_r <= 1;
//                        if ((SDA_i == 1) && (SCL_i == 1))
                            if (1==1)
                            begin
                                ERROR <= 10;
                                count <= SPD;                                             
                                STATE <= 201;
                            end
                        else
                            begin
                                ERROR <= 11; // нельзя сделать START
                                STATE <= 0;
                            end        
                    end  
                201:
                    begin
                        if (count == 0)
                            begin
                                SDA_r <= 0;
                                count <= SPD;
                                STATE <= 202;
                            end
                        else
                            count <= count-1;    
                    end
                202:
                    begin
                        if (count == 0)             
                            begin
                                STATE <= 19;        //++++ ВЫХОД ++++//
                            end
                        else
                            count <= count-1;    
                    end
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
                
                
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% STOP %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//                 
                 210: // STOP
                    begin
                        STOP <= 0;
                        SDA_r <= 0;
                        SCL_r <= 0;
                        if (1 == 1)
                            begin
                                ERROR <= 0;
                                count <= SPD/2;          
                                STATE <= 211;
                            end
                        else
                            begin
                                ERROR <= 2; // нельзя сделать STOP
                                STATE <= 0;
                            end       
                    end
                211:
                    begin
                        if (count == 0)
                            begin
                                SCL_r <= 1;
                                count <= SPD/2;           
                                STATE <= 212;
                            end
                        else
                            count <= count-1;    
                    end
               212:
                    begin
                        if (count == 0)              
                            begin
                                SDA_r <= 1; 
                                STATE <= 0;
                            end
                        else
                            count <= count-1;          
                    end
                //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%//
            
            endcase
            //::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
            
			if (M2S_RQ) 
			begin
				if (M2S_RW) 
				    begin
                        case (M2S_Addr) 
                            0:  S2M_Data <= 32'h28102021;             // Версия-Дата
                            2:  S2M_Data <= START;                    // Старт  
                            3:  S2M_Data <= STOP;                     // Выходное
                            4:  S2M_Data <= SEND_BYTE;
                            5:  S2M_Data <= STATE;
                            6:  S2M_Data <= ERROR;
                            8:  S2M_Data <= ACK;
                            9:  S2M_Data <= SLAVE_ADDR;
                            10: S2M_Data <= CELL_ADDR;
                            11: S2M_Data <= PACKAGE;
                            12: S2M_Data <= RECEIVE_BYTE;
                            13: S2M_Data <= Done;
                            default:  S2M_Data <= 32'h0000_0BAD;
                        endcase
				    end
				else 
                    begin
                        case (M2S_Addr) 
                            1:  Global_reset <= 1;
                            2:  
                                  begin
                                      START <= 1;
                                      START <= M2S_Data[31:0];
                                      STATE <= 200;  // START
                                      NEXT  <= 0;
                                  end
                            3:
                                  begin
                                      STOP  <= 1;
                                      STATE <= 210; // STOP
                                      NEXT  <= 0;
                                      
                                  end
                            9: 
                                begin
                                    SLAVE_ADDR <=  M2S_Data[7:0];
                                    STATE <= 19;
                                end
                            10:
                                begin
                                    CELL_ADDR <=  M2S_Data[7:0];     
                                end
                            11:
                                begin
                                    PACKAGE <= M2S_Data[7:0];                                    
                                end
                             
                        endcase	                      
                    end

			     end

	end
    //*******************************************************************************************************// 
    //*******************************************************************************************************//   
	ila_0 ILA_test (
        .clk(CLK),     
//        .probe0({ERROR, START, STOP, SEND_BYTE,flag,SDA_r, SDA_i,SCL_r, SCL_i,STATE ,ACK, NUM_PACK, bit_sending}),
//        .probe1({count, SLAVE_ADDR, NEXT}),
//        .probe2({byte_to_send, pack_sending, currentTact, newTact}),
//        .probe3({WRITE_BYTE})                                                       // input wire         clk

        .probe0({ERROR, START, STOP, SEND_BYTE,flag,SDA_r, SDA_i,SCL_r, SCL_i,
                 STATE ,ACK, NUM_PACK, pack_rec, pack_sending,bit_sending,Done}),
        .probe1({PACK_RECEIVED, SLAVE_ADDR, NEXT, byte_to_send, numOfOperation,RW}),
        .probe2({RECEIVE_BYTE, bit_received, SLAVE_ADDR_READ}),
        .probe3({READ_BYTE})

    );
endmodule