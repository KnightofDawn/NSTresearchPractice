function deleteAllTimers(hObj, eventdata)
fprintf(1,'Experiment finished!\nClosing figures and timers...\n')
delete(timerfind)
close all
fprintf(1,'Done.\n')
end

