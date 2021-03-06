//+------------------------------------------------------------------+
//|                                                           H4.mq5 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"


int mm_lenta_Handle;      // Handle controlador da média móvel lenta
double mm_lenta_Buffer[]; // Buffer para armazenamento dos dados das médias

int magic_number = 1234567;   // Nº mágico do robô

MqlRates velas[];            // Variável para armazenar velas
MqlTick tick;                // variável para armazenar ticks

int mm_lenta_periodo = 200;

double ultimaCompra;
double num_lotes = 0.01;
double TK = 300;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   mm_lenta_Handle  = iMA(_Symbol, PERIOD_H4, mm_lenta_periodo, 0, MODE_SMA, PRICE_CLOSE);
   CopyRates(_Symbol,_Period,0,4,velas);
   ArraySetAsSeries(velas,true);   
   ChartIndicatorAdd(0,0,mm_lenta_Handle);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(mm_lenta_Handle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
      CopyBuffer(mm_lenta_Handle,0,0,4,mm_lenta_Buffer);
      CopyRates(_Symbol,_Period,0,4,velas);
      ArraySetAsSeries(velas,true);
      ArraySetAsSeries(mm_lenta_Buffer,true);
      SymbolInfoTick(_Symbol,tick);
      
      bool Comprar = false;
      bool FecharCompra = false;
    
      if(PositionSelect(_Symbol)==false)
         {
            num_lotes = 0;
            Comprar = mm_lenta_Buffer[0] > velas[1].close && 
            (NormalizeDouble(mm_lenta_Buffer[0], _Digits) - NormalizeDouble(velas[1].close, _Digits)) >= 1;
         }
      
      if(PositionSelect(_Symbol)==true)
         {                          
            Comprar = mm_lenta_Buffer[0] > velas[1].close && 
            PositionGetDouble(POSITION_PRICE_OPEN) > velas[1].close && 
            (PositionGetDouble(POSITION_PRICE_OPEN) - velas[1].close) >= 0.5;
            
            FecharCompra =
            PositionGetDouble(POSITION_PRICE_OPEN) < velas[1].close && 
            (velas[1].close - PositionGetDouble(POSITION_PRICE_OPEN)) >= 0.3;
            
         }
         
      if(PositionSelect(_Symbol) && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < 300) 
         {
            Print("Parei de Compra chega");
            Comprar = false;  
         }   

      if(TemosNovaVela())
         { 
            if(Comprar)
               {
                  desenhaLinhaVertical("Compra",velas[1].time,clrBlue);
                  CompraAMercado();
               }
            Print("Fecha a compra? " + FecharCompra);   
            if(FecharCompra)
               {
                  FechaCompra();
               }
         }                                   
  }
  
void CompraAMercado() // bser na documentação ordem das variaveis!!!
  {
  
  Print("Preço atual "+ PositionGetDouble(POSITION_PRICE_CURRENT));
  Print("Volume atual " +NormalizeDouble(PositionGetDouble(POSITION_VOLUME), _Digits));
  Print("Margem free " +AccountInfoDouble(ACCOUNT_MARGIN_FREE));
  Print("Margem level " +AccountInfoDouble(ACCOUNT_MARGIN_LEVEL));
  Print("Lote compra" + num_lotes);
  
  ultimaCompra = NormalizeDouble(tick.ask,_Digits);
  
   MqlTradeRequest   requisicao;    // requisição
   MqlTradeResult    resposta;      // resposta
   
   ZeroMemory(requisicao);
   ZeroMemory(resposta);
   
   //--- Cacacterísticas da ordem de Compra
   requisicao.action       = TRADE_ACTION_DEAL;                            // Executa ordem a mercado
   requisicao.magic        = magic_number;                                 // Nº mágico da ordem
   requisicao.symbol       = _Symbol;                                      // Simbolo do ativo
   requisicao.volume       = 0.01;                                     // Nº de Lotes
   requisicao.price        = ultimaCompra;            // Preço para a compra
   requisicao.deviation    = 0;                                            // Desvio Permitido do preço
   requisicao.type         = ORDER_TYPE_BUY;                               // Tipo da Ordem
   requisicao.type_filling = ORDER_FILLING_FOK;                            // Tipo deo Preenchimento da ordem
   
   //---
   OrderSend(requisicao,resposta);
   //---
   if(resposta.retcode == 10008 || resposta.retcode == 10009)
     {
      Print("Ordem de Compra executada com sucesso!");
     }
   else
     {
       Print("Erro ao enviar Ordem Compra. Erro = ", GetLastError());
       ResetLastError();
     }
  }
 
void FechaCompra()
   {
      MqlTradeRequest   requisicao;    // requisição
      MqlTradeResult    resposta;      // resposta
      
      ZeroMemory(requisicao);
      ZeroMemory(resposta);
      
      //--- Cacacterísticas da ordem de Venda
      requisicao.action       = TRADE_ACTION_DEAL;
      requisicao.magic        = magic_number;
      requisicao.symbol       = _Symbol;
      requisicao.volume       = NormalizeDouble(PositionGetDouble(POSITION_VOLUME), _Digits); 
      requisicao.price        = 0; 
      requisicao.type         = ORDER_TYPE_SELL;
      requisicao.type_filling = ORDER_FILLING_FOK;
      
      //---
      OrderSend(requisicao,resposta);
      //---
        if(resposta.retcode == 10008 || resposta.retcode == 10009)
          {
           Print("Ordem de Venda executada com sucesso!");
          }
        else
          {
           Print("Erro ao enviar Ordem Venda. Erro = ", GetLastError());
           ResetLastError();
          }
   }    
  
void desenhaLinhaVertical(string nome, datetime dt, color cor = clrBlueViolet)
   {
      ObjectDelete(0,nome);
      ObjectCreate(0,nome,OBJ_VLINE,0,dt,0);
      ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   } 

bool TemosNovaVela()
  {
//--- memoriza o tempo de abertura da ultima barra (vela) numa variável
   static datetime last_time=0;
//--- tempo atual
   datetime lastbar_time= (datetime) SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- se for a primeira chamada da função:
   if(last_time==0)
     {
      //--- atribuir valor temporal e sair
      last_time=lastbar_time;
      return(false);
     }

//--- se o tempo estiver diferente:
   if(last_time!=lastbar_time)
     {
      //--- memorizar esse tempo e retornar true
      last_time=lastbar_time;
      return(true);
     }
//--- se passarmos desta linha, então a barra não é nova; retornar false
   return(false);
  }   
   