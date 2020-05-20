pragma solidity =0.6.6;

import './libraries/SafeMath.sol';
import './interfaces/IERC20.sol';
import './libraries/UQ112x112.sol';
import './libraries/Math.sol';

contract NanoperpetualPair is IERC20, NanoperpetualERC20{
    using SafeMath  for uint;

    address public factory;
    
    //a stable coin consists of
    // a reserve token
    // a price oracle
    // an interest rate
    address public reserveToken; //the backing token
    address public syntheticToken;
    address public oracle;
    //an oracle has a function that looks like
    // function consult(address tokenIn, uint amountIn, address tokenOut) external view returns (uint amountOut)
    //all of these are multiplied by 2**18
    uint256 creationRatio;
    uint256 liquidationRatio;
    uint solvencyRatio;


    //interal stuff
    mapping(address => uint) public amountCreated;
    mapping(address => uint) public amountReserves;

    //keep track of market failure
    uint insolventCount=0
    mapping(address=>bool) public insolventCreators;



    uint DECIMALS = 2**18;
    
    //contract creation

    //ERC20 interface

    //stablecoin interface
    //mint $amount of stablecoin
    public mintStablecoin(address sender, uint amount){
        uint newAmount = amountCreated[sender]+amount;
        uint computedReserves=oracle.consult(reserveToken,amountReserves[sender],syntheticToken);
        uint neededReserves=newAmount.mul(creationRatio).div(DECIMALS);
        require(computedReserves >= neededReserves)

        //balances
        _mint(sender, amount);
        amountCreated[sender] = newAmount;
        

    }

    //opposite of mint action
    // the user burns $amount of stablecoin
    public burnStablecoin(address sender, uint amount){
        require(balanceOf[sender]>=amount)
        newAmount=amountCreated[sender]-amount;

        //balances
        _burn(sender,amount);
        amountCreated[sender]=newAmount;

        
    }

    //liquidate a minter with insufficient reserves
    public liqiudate(address sender, address reserveHolder, uint amount){
        require(balanceOf[sender]>=amount)
        //not handling fractional liquidation for now
        require(amountCreated[reserveHolder]==amount)

        //is this account subjet to liquidation?
        uint computedReserves=oracle.consult(reserveToken,amountReserves[reserveHolder],syntheticToken);
        uint liquidationRatio=amountCreated[sender].mul(liquidationRatio).div(DECIMALS);
        require(computedReserves<liquidationRatio)

        _burn(sender,amount);
        reserveToken.transfer(this,sender,amountReserves[reserveHolder]);
        amountReserves[reserveHolder]=0;
        amountCreated[reserveHolder]=0;


    }

    //redeem stablecoin
    public redeem(address sender, address reserveHolder, uint amount){
        //can't redeem what you don't have
        require(balanceOf[sender]>=amount);        
        //can't redeem from someone who hasn't created
        require(amountCreated[reserveHolder]>=amount);
        //how much are you owed?        
        uint reservesOwed=oracle.consult(syntheticToken,amount,reserveToken);
        
        //this case should rarely happen (reserves are insufficient to reimburse sender)
        if(amountReserves[reserveHolder]<reservesOwed){
            liquidate(sender,reserveHolder,amount);
        }else{
            //remove stablecoins from sender
            _burn(sender,amount)
            //reduce reserves of reserveHolder
            amountCreated[reserveHolder]-=amount;
            amountReserves[reserveHolder]-=reservesOwed;
            
        }

    }
    
    //add reserves
    public addReserves(address sender, uint amount){
        token.transfer(this,sender,amount);
        amountReserves[sender]+=amount;
    }

    //remove reserves
    public drainReserves(address sender, uint amount){

        uint newReserves=amountReserves[sender]-amount;
        uint computedReserves=oracle.consult(reserveToken,newReserves,syntheticToken);
        uint neededReserves=amountCreated[sender].mul(creationRatio).div(DECIMALS);
        require(computedReserves >= neededReserves);

        //balances
        token.transfer(sender,this,amount);
        amountReserves[sender]-=amount;
        
    }

    //market failure
    public markInsolvent(address sender, address reserveHolder){
        //verify that reserve holder is insolvent
        uint computedReserves=oracle.consult(reserveToken,amountReserves[reserveHolder],syntheticToken);
        uint neededReserves=newAmount.mul(solvencyRatio).div(DECIMALS);
        require(neededReserves<amountCreated[reserveHolder]);

        //mark as insolvent and increase count (if not already)
        if(!insolventCreators[reserveHolder]){
            insolventCreators[reserveHolder]=true;
            insolventCount+=1;
        }


    }

    public markSolvent(address sender, address reserveHolder){

         //verify that reserve holder is insolvent
        uint computedReserves=oracle.consult(reserveToken,amountReserves[reserveHolder],syntheticToken);
        uint neededReserves=newAmount.mul(solvencyRatio).div(DECIMALS);
        require(neededReserves>=amountCreated[reserveHolder]);

        //mark as not insolvent and increase count (if not already)
        if(insolventCreators[reserveHolder]){
            insolventCreators[reserveHolder]=false;
            insolventCount-=1;
        }
    }



}
