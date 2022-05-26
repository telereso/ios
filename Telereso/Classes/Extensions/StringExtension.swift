//
//  TStringExtension.swift
//  Telereso
//
//  Created by Ganesh TR on 04/05/22.
//

extension String{
   public func remoteLocale() -> String {
        Telereso.getRemoteString(self)
    }
    
    public func remoteLocaleWith(args: [CVarArg]) -> String {
        Telereso.getRemoteString(self, args: args)
    }
    
    func stringWithParams(_ args: [CVarArg]) -> String {
        return String(format: self, arguments: args)
    }
}


