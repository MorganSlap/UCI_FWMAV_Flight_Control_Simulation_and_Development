function [specificForce,gyro]=idealImu(x,du,m,g,C11,linearDrag,quadraticDrag,nonlinear)
%IDEALIMU Physical center-of-mass IMU in aircraft body FRD coordinates.
% Accelerometers measure non-gravitational force / mass, not gravity alone.
% In tilted free flight, thrust remains along body -Z. At supported rest the
% support force is different; startup calibration models that separately.
%#codegen
velocity=x(4:6);
if nonlinear
    force=-quadraticDrag.*abs(velocity).*velocity;
else
    force=-linearDrag.*velocity;
end
specificForce=force/m+[0;0;-g-C11*sum(du)/m];
gyro=x(10:12);
end
