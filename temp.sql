# I'm adding one line of change here.


--Primary Market Sales by Event (Event Sales Summary [Trx Date Range])
--Allyson Miller, Tickets.com, 08-Jun-2016
--Any SQL code provided is intended as a demonstration of the relationships and logical groupings of ProVenue® data.  It does not consider business logic variables that may be relevant as part of the setup and configuration of ProVenue or any business process or procedure that may result in transactions that are unique to a client.  The client assumes responsibility for testing the results of any application of this SQL to a specific ProVenue domain.  
Select

  EVENT_DATE
, EVENT_CODE AS EventCd
, case when extract(month from (CURRENT_DATE())) < 11 then extract(year from (CURRENT_DATE())) else extract(year from (CURRENT_DATE()))+1 end -1 AS Prior_Year
, case when extract(month from (CURRENT_DATE())) < 11 then extract(year from (CURRENT_DATE())) else extract(year from (CURRENT_DATE()))+1 end AS Current_Year
, TRANSACTION_DATE
, BUYER_TYPE_GROUP_CODE
, CASE WHEN (Event_Code = '19RS0807' and Buyer_type_group_code = 'SNGFUL' and Transaction_date = '2019-08-07 21:29:20.6870') 
    THEN (Noncomp_Sale_Qty + Noncomp_Return_Qty + Comp_Sale_Qty + Comp_Return_Qty + 9125)
    ELSE (Noncomp_Sale_Qty + Noncomp_Return_Qty + Comp_Sale_Qty + Comp_Return_Qty) END As TICKETS
, ((Sale_Amount + Return_Amount)-(SC_Sale_Amount + SC_Return_Amount)) AS Revenue

From

      (Select
      Event.EVENT_DATE
      , Event.Event_Code As Event_Code
      , TRANSACTION_DATE
      , BUYER_TYPE_GROUP_CODE
      , Count (Case When Ticket.Price <> 0 And Oli.Transaction_Type_Code In ('SA','ES','CS')
         Then Ticket.Ticket_Id End) As Noncomp_Sale_Qty
      , Count (Case When Ticket.Price <> 0 And Oli.Transaction_Type_Code In ('RT','ER')
         Then Ticket.Ticket_Id End) * -1 As Noncomp_Return_Qty
      , Count (Case When Ticket.Price = 0 And Oli.Transaction_Type_Code In ('SA','ES','CS')
         Then Ticket.Ticket_Id End) As Comp_Sale_Qty
      , Count (Case When Ticket.Price = 0 And Oli.Transaction_Type_Code In ('RT','ER')
         Then Ticket.Ticket_Id End) * -1 As Comp_Return_Qty
      , IFNULL (Sum(Case When Oli.Transaction_Type_Code In ('SA','ES','CS') 
         Then Ticket.Price End), 0.00) As Sale_Amount --We don't have to filter on Ticket Price because comps have no value.
      , IFNULL (Sum(Case When Oli.Transaction_Type_Code In ('RT','ER') 
         Then Ticket.Price End), 0.00) * -1 As Return_Amount --We don't have to filter on Ticket Price because comps have no value.
      , IFNULL (Sum(Case When Oli.Transaction_Type_Code In ('SA','ES','CS') 
         Then SCI.Actual_Amount End), 0.00) As SC_Sale_Amount --We don't have to filter on Ticket Price because comps have no value.
      , IFNULL (Sum(Case When Oli.Transaction_Type_Code In ('RT','ER') 
         Then SCI.Actual_Amount End), 0.00) * -1 As SC_Return_Amount --We don't have to filter on Ticket Price because comps have no value.
      From `brs-clouddata-prod.stage.tdc__brs__TICKET__latest` Ticket
      Inner Join `brs-clouddata-prod.stage.tdc__brs__ORDER_LINE_ITEM__latest` Oli
      On Ticket.Order_Line_Item_Id = Oli.Order_Line_Item_Id
      Or Ticket.Remove_Order_Line_Item_Id = Oli.Order_Line_Item_Id --We join tickets based on any/either order line item relationship.
      Inner Join `brs-clouddata-prod.stage.tdc__brs__EVENT__latest` Event
      On Oli.Event_Id = Event.Event_Id
      Inner Join `brs-clouddata-prod.stage.tdc__brs__EVENT__latest` Uevent --Different alias to distinguish the usage event.
      On Oli.Usage_Event_Id = Uevent.Event_Id
      Inner Join `brs-clouddata-prod.stage.tdc__brs__ORDER_TRANSACTION__latest` Ot
      On Oli.Order_Id = Ot.Order_Id And Oli.Transaction_Id = Ot.Transaction_Id
      Inner Join `brs-clouddata-prod.stage.tdc__brs__TRANSACTION__latest` Transaction
      On Oli.Transaction_Id = Transaction.Transaction_Id 
      Left Join (select TICKET_ID, ORDER_ID, SUM(ACTUAL_AMOUNT) AS ACTUAL_AMOUNT
                from `brs-clouddata-prod.stage.tdc__brs__SERVICE_CHARGE_ITEM__latest` SCI
                inner join `brs-clouddata-prod.stage.tdc__brs__SERVICE_CHARGE__latest` SC
                on SCI.SERVICE_CHARGE_ID = SC.SERVICE_CHARGE_ID
                and INCLUDE_IN_TICKET_PRICE = 1
                GROUP BY TICKET_ID, ORDER_ID) SCI
      On SCI.TICKET_ID = Ticket.TICKET_ID
      LEFT JOIN `brs-clouddata-prod.stage.tdc__brs__BUYER_TYPE` BT        
          on BT.BUYER_TYPE_ID = Ticket.BUYER_TYPE_ID   
      LEFT JOIN `brs-clouddata-prod.stage.tdc__brs__BUYER_TYPE_GROUP` BG       
          on BG.BUYER_TYPE_GROUP_ID = BT.REPORT_BUYER_TYPE_GROUP_ID  
      Where Oli.Market_Type_Code = 'P' --This filters any secondary market tickets removed or added by resale, transfer and donation transactions.
      And IFNULL(Ot.Order_Trxn_Assoc_Type_Code,'X') <> 'SI' --This filters any primary market tickets that are reinstatements. IFNULL needed because code can be null.
      And (extract(year from (Event.EVENT_DATE)) = case when extract(month from (CURRENT_DATE())) < 11 then extract(year from (CURRENT_DATE())) else extract(year from (CURRENT_DATE()))+1 end
              OR extract(year from (Event.EVENT_DATE)) = case when extract(month from (CURRENT_DATE())) < 11 then extract(year from (CURRENT_DATE())) else extract(year from (CURRENT_DATE))+1 end -1)
      and (Event.Event_Code LIKE '%RS%'
        or Event.Event_Code LIKE '%LF%'
        or Event.Event_Code LIKE '%CA%'
        or Event.Event_Code LIKE '%GM%'
        or Event.Event_Code LIKE 'RS%T%LFE'
      )
      and Event.Event_Code not LIKE 'RS%VE'
      
      
      
      Group By
      Event.Event_Date
      , Event.Event_Code 
      , TRANSACTION_DATE
      , BUYER_TYPE_GROUP_CODE)