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
}


