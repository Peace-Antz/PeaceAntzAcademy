pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT


contract CourseContract {

    bool public courseStatus;
    bool public signupStatus;
    uint public payment;
    uint public studentStake;


    event GrantRole(bytes32 indexed role, address indexed account);
    event RevokeRole(bytes32 indexed role, address indexed account);
    event DropOut(bytes32 indexed role, address indexed account);
    event CourseStatus(bool indexed courseStatus);
    event SignupStatus(bool indexed signupStatus);
    event StudentEnrolled(address indexed account);
    event CourseCompleted(bool indexed pass, address indexed account);

    // struct Stake {
    //     uint72 tokenAmount;                   // Amount of tokens locked in a stake                                                                            
    //     uint128 expectedStakingRewardPoints;  // The amount of RewardPoints the stake will earn if not unlocked prematurely    
    // }

    //role => account = bool
    mapping(bytes32 => mapping(address => bool)) public roles;

    //Staking & Sponsoring
    mapping (address => uint) public studentDeposit;
    mapping (address => uint) public sponsorDeposit;
    mapping (address => bool) public courseCompleted;
    // // Function to receive Ether. msg.data must be empty
    // receive() external payable {}
    // // Fallback function is called when msg.data is not empty
    // fallback() external payable {}

    // function getBalance() public view returns (uint) {
    //     return address(this).balance;
    // }
    
    // function sendViaCall(address payable _to) public payable {
    //     // Call returns a boolean value indicating success or failure.
    //     // This is the current recommended method to use.
    //     (bool sent, bytes memory data) = _to.call{value: msg.value}("");
    //     require(sent, "Failed to send Ether");
    // }


    //0xdf8b4c520ffe197c5343c6f5aec59570151ef9a492f2c624fd45ddde6135ec42
    bytes32 private constant ADMIN = keccak256(abi.encodePacked("ADMIN"));
    //0x534b5b9fe29299d99ea2855da6940643d68ed225db268dc8d86c1f38df5de794
    bytes32 private constant TEACHER = keccak256(abi.encodePacked("TEACHER"));
    //0xc951d7098b66ba0b8b77265b6e9cf0e187d73125a42bcd0061b09a68be421810
    bytes32 private constant STUDENT = keccak256(abi.encodePacked("STUDENT"));
    //0x5f0a5f78118b6e0b700e0357ae3909aaafe8fa706a075935688657cf4135f9a9
    bytes32 private constant SPONSOR = keccak256(abi.encodePacked("SPONSOR"));

    modifier onlyRole(bytes32 _role){
        require(roles[_role][msg.sender], "not authorized");
        _;
    }

    constructor() payable{
        _grantRole(ADMIN, msg.sender);
        _grantRole(TEACHER, msg.sender);
    }

//Admin Functions
    function _grantRole(bytes32 _role, address _account) internal{
        roles[_role][_account] = true;
        emit GrantRole(_role, _account);
    }

    function grantRole(bytes32 _role, address _account) external onlyRole(ADMIN){
        _grantRole(_role,_account);
    }

    function revokeRole(bytes32 _role, address _account) external onlyRole(ADMIN){
        roles[_role][_account] = false;
        emit RevokeRole(_role, _account);
    }

//Teacher Functions

    function updateCourseStatus() external onlyRole(TEACHER){
        courseStatus=true;
        signupStatus=false;
        emit CourseStatus(true);
        emit SignupStatus(false);
    }

    function setAmount(uint _payment) external onlyRole(TEACHER){
        payment = _payment;
        unchecked {
            studentStake= _payment/15;
        }
        signupStatus=true;
        emit SignupStatus(true);
    }
    
    function passStudent(address _account) external onlyRole(TEACHER){

        courseCompleted[_account]=true;
        emit CourseCompleted(true,_account);
    }
    function bootStudent(address _account) external{}
    function claimPayment(uint _payment) external{}


//Student Functions
    function enroll()external payable{ 
        require(msg.value == studentStake, "Please Stake the Correct Amount");
        require(courseStatus == false, "Course has already started :(");
        require(!roles[STUDENT][msg.sender],"You are enrolled already!");
        require(signupStatus == true, "Enrollment Closed");
        studentStake = msg.value;
        roles[STUDENT][msg.sender] = true;
        emit StudentEnrolled(msg.sender);
    }
    function withdraw () external {
        require(roles[STUDENT][msg.sender],"You are not enrolled!");
        require(address(this).balance >0, "No balance available");
        require(courseStatus == false, "You have to dropout because the course has started.");
        address sender = address(msg.sender);
        sender.transfer(studentStake);

    }

    function dropOut(bytes32 _role, address _account) external onlyRole(STUDENT){
        //need to add sending staked amout to multisig address
        roles[_role][_account] = false;
        emit DropOut(_role, _account);
    }


//Sponsor Functions
    function sponsor(uint _sponsor) external {}
    function unsponsor(uint _unsponsor) external {}

}
