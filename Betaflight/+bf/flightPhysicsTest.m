function tests=flightPhysicsTest
%FLIGHTPHYSICSTEST Physical limiting cases for the installed IMU boundary.
tests=functiontests(localfunctions);
end

function testFreeFallReadsZeroSpecificForce(testCase)
x=zeros(12,1); x(7:8)=[0.3;-0.2]; m=0.11; g=9.81; coefficient=0.000458;
du=-m*g/(4*coefficient)*ones(4,1);
for nonlinear=[false true]
    [a,w]=bf.idealImu(x,du,m,g,coefficient,zeros(3,1),zeros(3,1),nonlinear);
    testCase.verifyEqual(a,zeros(3,1),'AbsTol',1e-12);
    testCase.verifyEqual(w,zeros(3,1));
end
end

function testTiltDoesNotRotateBodyThrust(testCase)
x=zeros(12,1); x(7:8)=[30;-15]*pi/180; x(10:12)=[0.1;-0.2;0.3];
[a,w]=bf.idealImu(x,zeros(4,1),0.11,9.81,0.000458,zeros(3,1),zeros(3,1),true);
testCase.verifyEqual(a,[0;0;-9.81],'AbsTol',1e-12);
testCase.verifyEqual(w,x(10:12));
end

function testDragOpposesVelocityAndScalesWithSpeed(testCase)
x=zeros(12,1); x(4:6)=[2;-2;2];
a=bf.idealImu(x,zeros(4,1),1,10,1,ones(3,1),ones(3,1),false);
b=bf.idealImu(x,zeros(4,1),1,10,1,ones(3,1),ones(3,1),true);
testCase.verifyEqual(a,[-2;2;-12]);
testCase.verifyEqual(b,[-4;4;-14]);
end

function testSteadyDriftingTiltRecoversGravityDirection(testCase)
% At terminal velocity, drag balances the horizontal gravity components.
% Specific force must then recover tilt even though thrust is body-aligned.
m=0.11; g=9.81; coefficient=0.000458;
x=zeros(12,1); x(7:8)=[10;-6]*pi/180;
gravityBody=g*[-sin(x(8));sin(x(7))*cos(x(8));cos(x(7))*cos(x(8))];
dragCoefficients=[0.15;0.15;0.10];
du=m*(gravityBody(3)-g)/(4*coefficient)*ones(4,1);
for nonlinear=[false true]
    speed=m*gravityBody(1:2)./dragCoefficients(1:2);
    if nonlinear, speed=sign(speed).*sqrt(abs(speed)); end
    x(4:5)=speed;
    a=bf.idealImu(x,du,m,g,coefficient,dragCoefficients,dragCoefficients,nonlinear);
    testCase.verifyEqual(a,-gravityBody,'AbsTol',1e-12);
    measuredTilt=[atan2(-a(2),-a(3));atan2(a(1),hypot(a(2),a(3)))];
    testCase.verifyEqual(measuredTilt,x(7:8),'AbsTol',1e-12);
end
end
