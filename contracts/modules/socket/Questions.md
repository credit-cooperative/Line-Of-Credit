### Design Choices

Should the Spigot module differentiate between 'owner' and 'creditPLug' or can they be the one and the same?

Same question goes for 'spigot address' for  Spigoted Line?
 - if so, we  dont  have  to change any of our modules at all, except maybe the fact that we have to send ether? Maybe we can just make sure the CreditPlug contract has ether?

For 'claimOperatorTokens' how do we bridge assets over to chainA?
 - this is the only function where this matters, everything else is state change

How does 'inbound' work? Seems to only be able to handle 1 function. Can it handle many?

Need to understand how the Socket contract works. If it acts as a central relay, then it probably can only call 'inbound'?